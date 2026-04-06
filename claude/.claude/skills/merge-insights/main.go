package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// --- Data structures ---

type MergeCommit struct {
	SHA     string
	Date    string // raw "2026-03-15 14:30:45 +0800"
	Message string
}

type MRData struct {
	IID              int
	Title            string
	Author           string
	Description      string
	CreatedAt        time.Time
	MergedAt         time.Time
	Assignees        []string
	PipelineRuns     int
	PipelineFailures int
}

type GitData struct {
	FilesChanged    int
	Insertions      int
	Deletions       int
	ChangedFiles    []string
	CommitMsgs      []string
	FirstCommitDate time.Time
}

type MergeRecord struct {
	SHA12, FullSHA     string
	Date, Branch, Type string
	MRData
	GitData
	TTMHours   *int
	CycleHours *int
	HasTests   bool
	HasDocs    bool
}

type FileRecord struct {
	SHA, Branch, Date, Type, File string
}

type GitLabClient struct {
	client    *http.Client
	token     string
	baseURL   string
	projectID int
}

// --- Regex patterns ---

var (
	branchRe    = regexp.MustCompile(`Merge branch '(.+)' into 'master'`)
	prefixRe    = regexp.MustCompile(`^(feature|bug|patch|refactor|doc)/`)
	fixSignalRe = regexp.MustCompile(`(?i)\b(fix(e[sd])?|bug|revert|repair|correct(ed|ion)?)\b|\bpatch(e[sd])?\s+(data|record|amount|balance)\b`)
	testFileRe  = regexp.MustCompile(`(^|/)spec/|_spec\.rb$|_test\.(rb|go|js|ts)$|(^|/)test/`)
	docFileRe   = regexp.MustCompile(`(?i)changelog|readme|\.md$|(^|/)doc/`)

	hotspotExclude   = regexp.MustCompile(`^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml)$`)
	rapidFixExclude  = regexp.MustCompile(`^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml|config/system_config\.yml)$`)
	bugTypeRe        = regexp.MustCompile(`\b(bug|patch)\b`)
)

func main() {
	since := "1 week ago"
	if len(os.Args) > 1 {
		since = os.Args[1]
	}

	token := os.Getenv("GITLAB_READONLY_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "ERROR: GITLAB_READONLY_TOKEN is not set")
		os.Exit(1)
	}

	parallel := 10
	if v := os.Getenv("MERGE_INSIGHTS_PARALLEL"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			parallel = n
		}
	}

	// Resolve project
	projectPath := resolveProjectPath()
	if projectPath == "" {
		fmt.Fprintln(os.Stderr, "ERROR: Could not determine project path from git remote")
		os.Exit(1)
	}

	glClient := &GitLabClient{
		client: &http.Client{
			Transport: &http.Transport{MaxIdleConnsPerHost: parallel},
			Timeout:   30 * time.Second,
		},
		token:   token,
		baseURL: "https://gitlab.abagile.com/api/v4",
	}

	projectID := glClient.resolveProjectID(projectPath)
	if projectID == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: Could not resolve project ID for %s\n", projectPath)
		os.Exit(1)
	}
	glClient.projectID = projectID

	// Collect merge commits
	merges := collectMergeCommits(since)
	if len(merges) == 0 {
		fmt.Println("---METADATA---")
		fmt.Println("mode: short")
		fmt.Println("total: 0")
		return
	}

	// Determine mode
	oldestDate := merges[len(merges)-1].Date
	daysSpan := computeDaysSpan(oldestDate)
	mode := "short"
	if daysSpan > 14 {
		mode = "long"
	}

	// Phase 1: Concurrent collection
	results := make([]*MergeRecord, len(merges))
	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for i, m := range merges {
		wg.Add(1)
		go func(idx int, mc MergeCommit) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			results[idx] = collectOneMerge(glClient, mc)
		}(i, m)
	}
	wg.Wait()

	// Phase 2: Classify and enrich
	var records []*MergeRecord
	for _, r := range results {
		if r == nil {
			continue
		}
		r.Type = classifyType(r.Branch, r.CommitMsgs, r.MRData.Title)
		r.TTMHours = computeHours(r.MRData.CreatedAt, r.MRData.MergedAt)
		r.CycleHours = computeHours(r.FirstCommitDate, r.MRData.MergedAt)
		r.HasTests = hasTestFiles(r.ChangedFiles)
		r.HasDocs = hasDocFiles(r.ChangedFiles)
		records = append(records, r)
	}

	// Phase 3: Output
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()

	// Collect side data for aggregate sections
	var allFiles []FileRecord
	authorCounts := map[string]int{}
	var ttmEntries, cycleEntries []struct {
		Branch string
		Hours  int
	}
	var sizes []int
	withTests, withoutTests := 0, 0
	withDocs, withoutDocs := 0, 0
	totalPipelineRuns, totalPipelineFailures := 0, 0
	reviewerCounts := map[string]int{}
	typeMap := map[string]string{} // fullSHA -> type

	for _, r := range records {
		typeMap[r.FullSHA] = r.Type

		for _, f := range r.ChangedFiles {
			allFiles = append(allFiles, FileRecord{
				SHA: r.FullSHA, Branch: r.Branch, Date: r.Date, Type: r.Type, File: f,
			})
		}

		author := r.MRData.Author
		if author == "" {
			author = "unknown"
		}
		authorCounts[author+"|"+r.Type]++

		if r.TTMHours != nil {
			ttmEntries = append(ttmEntries, struct {
				Branch string
				Hours  int
			}{r.Branch, *r.TTMHours})
		}
		if r.CycleHours != nil {
			cycleEntries = append(cycleEntries, struct {
				Branch string
				Hours  int
			}{r.Branch, *r.CycleHours})
		}

		sizes = append(sizes, r.Insertions)

		if r.HasTests {
			withTests++
		} else {
			withoutTests++
		}
		if r.HasDocs {
			withDocs++
		} else {
			withoutDocs++
		}

		totalPipelineRuns += r.PipelineRuns
		totalPipelineFailures += r.PipelineFailures

		for _, a := range r.MRData.Assignees {
			if a != "" {
				reviewerCounts[a]++
			}
		}
	}

	// --- MERGE records ---
	for i, r := range records {
		if i > 0 {
			// The bash version uses heredoc which adds no blank line between records
		}
		printMergeRecord(w, r)
	}

	// --- HOTSPOTS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---HOTSPOTS---")
	printHotspots(w, allFiles)

	// --- RAPID-FIXES ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---RAPID-FIXES---")
	printRapidFixes(w, allFiles, records)

	// --- WEEKLY-DENSITY ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---WEEKLY-DENSITY---")
	printWeeklyDensity(w, merges, typeMap)

	// --- AUTHORS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---AUTHORS---")
	printCountMap(w, authorCounts)

	// --- REVIEW-METRICS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REVIEW-METRICS---")
	printReviewMetrics(w, ttmEntries, cycleEntries)

	// --- SIZE-DISTRIBUTION ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---SIZE-DISTRIBUTION---")
	printSizeDistribution(w, sizes)

	// --- TEST-COVERAGE ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---TEST-COVERAGE---")
	total := withTests + withoutTests
	ratio := 0
	if total > 0 {
		ratio = withTests * 100 / total
	}
	fmt.Fprintf(w, "with_tests: %d\n", withTests)
	fmt.Fprintf(w, "without_tests: %d\n", withoutTests)
	fmt.Fprintf(w, "ratio: %d%%\n", ratio)

	// --- DOC-CHANGES ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---DOC-CHANGES---")
	fmt.Fprintf(w, "with_docs: %d\n", withDocs)
	fmt.Fprintf(w, "without_docs: %d\n", withoutDocs)

	// --- PIPELINE-HEALTH ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---PIPELINE-HEALTH---")
	failRate := 0
	if totalPipelineRuns > 0 {
		failRate = totalPipelineFailures * 100 / totalPipelineRuns
	}
	fmt.Fprintf(w, "total_runs:%d\n", totalPipelineRuns)
	fmt.Fprintf(w, "total_failures:%d\n", totalPipelineFailures)
	fmt.Fprintf(w, "failure_rate:%d%%\n", failRate)

	// --- REVIEWERS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REVIEWERS---")
	printCountMapRaw(w, reviewerCounts)

	// --- METADATA ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---METADATA---")
	fmt.Fprintf(w, "mode: %s\n", mode)
	fmt.Fprintf(w, "total: %d\n", len(records))
	fmt.Fprintf(w, "days_span: %d\n", daysSpan)
	fmt.Fprintf(w, "since: %s\n", since)
	fmt.Fprintf(w, "project: %s (ID: %d)\n", projectPath, projectID)
}

// --- Project resolution ---

func resolveProjectPath() string {
	out, err := exec.Command("git", "remote", "get-url", "origin").Output()
	if err != nil {
		return ""
	}
	raw := strings.TrimSpace(string(out))

	// Strip SSH prefix: ssh://git@gitlab.abagile.com:7788/group/project.git
	raw = regexp.MustCompile(`^ssh://git@[^/]+/`).ReplaceAllString(raw, "")
	// Strip git@ prefix: git@gitlab.abagile.com:group/project.git
	raw = regexp.MustCompile(`^git@[^:]+:`).ReplaceAllString(raw, "")
	// Strip https prefix
	raw = regexp.MustCompile(`^https://[^/]+/`).ReplaceAllString(raw, "")
	// Strip .git suffix
	raw = strings.TrimSuffix(raw, ".git")

	return raw
}

func (gl *GitLabClient) resolveProjectID(path string) int {
	encoded := url.PathEscape(path)
	// url.PathEscape encodes / as %2F which is what we need
	resp, err := gl.get(fmt.Sprintf("/projects/%s", encoded))
	if err != nil {
		return 0
	}
	defer resp.Body.Close()

	var result struct {
		ID int `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0
	}
	return result.ID
}

func (gl *GitLabClient) get(path string) (*http.Response, error) {
	req, err := http.NewRequest("GET", gl.baseURL+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("PRIVATE-TOKEN", gl.token)
	return gl.client.Do(req)
}

// --- Merge commit collection ---

func collectMergeCommits(since string) []MergeCommit {
	out, err := exec.Command("git", "log", "master", "--merges", "--first-parent",
		"--since="+since, "--format=%H|%ai|%s").Output()
	if err != nil {
		return nil
	}
	var merges []MergeCommit
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "|", 3)
		if len(parts) != 3 {
			continue
		}
		merges = append(merges, MergeCommit{SHA: parts[0], Date: parts[1], Message: parts[2]})
	}
	return merges
}

func computeDaysSpan(oldestDateStr string) int {
	datePart := strings.Fields(oldestDateStr)[0]
	t, err := time.Parse("2006-01-02", datePart)
	if err != nil {
		return 0
	}
	return int(time.Since(t).Hours() / 24)
}

// --- Phase 1: Concurrent collection per merge ---

func collectOneMerge(gl *GitLabClient, mc MergeCommit) *MergeRecord {
	matches := branchRe.FindStringSubmatch(mc.Message)
	if matches == nil {
		return nil
	}
	branch := matches[1]

	r := &MergeRecord{
		SHA12:  mc.SHA[:12],
		FullSHA: mc.SHA,
		Date:   strings.Fields(mc.Date)[0],
		Branch: branch,
	}

	// GitLab MR API
	encodedBranch := url.QueryEscape(branch)
	resp, err := gl.get(fmt.Sprintf("/projects/%d/merge_requests?state=merged&source_branch=%s&per_page=1",
		gl.projectID, encodedBranch))
	if err == nil {
		defer resp.Body.Close()
		var mrs []struct {
			IID         int    `json:"iid"`
			Title       string `json:"title"`
			Author      struct {
				Name string `json:"name"`
			} `json:"author"`
			Description string `json:"description"`
			CreatedAt   string `json:"created_at"`
			MergedAt    string `json:"merged_at"`
			Assignees   []struct {
				Name string `json:"name"`
			} `json:"assignees"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&mrs); err == nil && len(mrs) > 0 {
			mr := mrs[0]
			r.MRData.IID = mr.IID
			r.MRData.Title = mr.Title
			r.MRData.Author = mr.Author.Name
			desc := strings.ReplaceAll(mr.Description, "\n", " ")
			if len(desc) > 200 {
				desc = desc[:200]
			}
			r.MRData.Description = desc
			r.MRData.CreatedAt = parseGitLabTime(mr.CreatedAt)
			r.MRData.MergedAt = parseGitLabTime(mr.MergedAt)
			for _, a := range mr.Assignees {
				if a.Name != "" {
					r.MRData.Assignees = append(r.MRData.Assignees, a.Name)
				}
			}
		}
	}

	// Pipeline API
	if r.MRData.IID > 0 {
		resp, err := gl.get(fmt.Sprintf("/projects/%d/merge_requests/%d/pipelines?per_page=100",
			gl.projectID, r.MRData.IID))
		if err == nil {
			defer resp.Body.Close()
			var pipelines []struct {
				Status string `json:"status"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&pipelines); err == nil {
				r.MRData.PipelineRuns = len(pipelines)
				for _, p := range pipelines {
					if p.Status == "failed" {
						r.MRData.PipelineFailures++
					}
				}
			}
		}
	}

	// Git shortstat
	if out, err := exec.Command("git", "diff", "--shortstat", mc.SHA+"^1..."+mc.SHA).Output(); err == nil {
		r.GitData.FilesChanged, r.GitData.Insertions, r.GitData.Deletions = parseShortstat(string(out))
	}

	// Git changed files
	if out, err := exec.Command("git", "diff", "--name-only", mc.SHA+"^1..."+mc.SHA).Output(); err == nil {
		for _, f := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			if f != "" {
				r.GitData.ChangedFiles = append(r.GitData.ChangedFiles, f)
			}
		}
	}

	// Git commit messages (max 5, each truncated to 120)
	if out, err := exec.Command("git", "log", mc.SHA+"^1..."+mc.SHA, "--format=%s", "--no-merges").Output(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		for i, l := range lines {
			if i >= 5 {
				break
			}
			if len(l) > 120 {
				l = l[:120]
			}
			if l != "" {
				r.GitData.CommitMsgs = append(r.GitData.CommitMsgs, l)
			}
		}
	}

	// Git first commit date
	if out, err := exec.Command("git", "log", mc.SHA+"^1..."+mc.SHA, "--reverse", "--format=%ai", "--no-merges").Output(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) > 0 && lines[0] != "" {
			r.GitData.FirstCommitDate = parseGitDate(lines[0])
		}
	}

	return r
}

// --- Parsing helpers ---

func parseGitLabTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	// Try RFC3339 first (handles +08:00 offset)
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t
	}
	// Try with milliseconds
	if t, err := time.Parse("2006-01-02T15:04:05.000Z", s); err == nil {
		return t
	}
	// Try with milliseconds and offset
	if t, err := time.Parse("2006-01-02T15:04:05.000-07:00", s); err == nil {
		return t
	}
	return time.Time{}
}

func parseGitDate(s string) time.Time {
	s = strings.TrimSpace(s)
	t, err := time.Parse("2006-01-02 15:04:05 -0700", s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func parseShortstat(s string) (files, insertions, deletions int) {
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		n := extractNumber(part)
		switch {
		case strings.Contains(part, "file"):
			files = n
		case strings.Contains(part, "insertion"):
			insertions = n
		case strings.Contains(part, "deletion"):
			deletions = n
		}
	}
	return
}

func extractNumber(s string) int {
	var num string
	for _, c := range s {
		if c >= '0' && c <= '9' {
			num += string(c)
		} else if num != "" {
			break
		}
	}
	n, _ := strconv.Atoi(num)
	return n
}

// --- Phase 2: Classification and metrics ---

func classifyType(branch string, commitMsgs []string, mrTitle string) string {
	prefix := ""
	if m := prefixRe.FindStringSubmatch(branch); m != nil {
		prefix = m[1]
	}

	// Trust explicit non-feature prefixes
	if prefix != "" && prefix != "feature" {
		return prefix
	}

	// For feature/ or unprefixed: scan for fix signals
	text := strings.ToLower(strings.Join(commitMsgs, "\n") + "\n" + mrTitle)
	if fixSignalRe.MatchString(text) {
		return "bug"
	}

	if prefix == "feature" {
		return "feature"
	}
	return "other"
}

func computeHours(start, end time.Time) *int {
	if start.IsZero() || end.IsZero() {
		return nil
	}
	h := int(end.Sub(start).Hours())
	return &h
}

func hasTestFiles(files []string) bool {
	for _, f := range files {
		if testFileRe.MatchString(f) {
			return true
		}
	}
	return false
}

func hasDocFiles(files []string) bool {
	for _, f := range files {
		if docFileRe.MatchString(f) {
			return true
		}
	}
	return false
}

// --- Phase 3: Output ---

func printMergeRecord(w *bufio.Writer, r *MergeRecord) {
	iid := "?"
	if r.MRData.IID > 0 {
		iid = strconv.Itoa(r.MRData.IID)
	}
	title := r.Branch
	if r.MRData.Title != "" {
		title = r.MRData.Title
	}
	author := "unknown"
	if r.MRData.Author != "" {
		author = r.MRData.Author
	}
	ttm := "?"
	if r.TTMHours != nil {
		ttm = strconv.Itoa(*r.TTMHours)
	}
	cycle := "?"
	if r.CycleHours != nil {
		cycle = strconv.Itoa(*r.CycleHours)
	}
	reviewers := "?"
	if len(r.MRData.Assignees) > 0 {
		reviewers = strings.Join(r.MRData.Assignees, ",")
	}
	hasTests := "no"
	if r.HasTests {
		hasTests = "yes"
	}
	hasDocs := "no"
	if r.HasDocs {
		hasDocs = "yes"
	}

	fmt.Fprintln(w, "---MERGE---")
	fmt.Fprintf(w, "sha: %s\n", r.SHA12)
	fmt.Fprintf(w, "date: %s\n", r.Date)
	fmt.Fprintf(w, "branch: %s\n", r.Branch)
	fmt.Fprintf(w, "type: %s\n", r.Type)
	fmt.Fprintf(w, "mr_iid: %s\n", iid)
	fmt.Fprintf(w, "mr_title: %s\n", title)
	fmt.Fprintf(w, "author: %s\n", author)
	fmt.Fprintf(w, "files_changed: %d\n", r.FilesChanged)
	fmt.Fprintf(w, "insertions: %d\n", r.Insertions)
	fmt.Fprintf(w, "deletions: %d\n", r.Deletions)
	fmt.Fprintf(w, "time_to_merge_hours: %s\n", ttm)
	fmt.Fprintf(w, "cycle_time_hours: %s\n", cycle)
	fmt.Fprintf(w, "reviewers: %s\n", reviewers)
	fmt.Fprintf(w, "has_tests: %s\n", hasTests)
	fmt.Fprintf(w, "has_docs: %s\n", hasDocs)
	fmt.Fprintf(w, "pipeline_runs: %d\n", r.PipelineRuns)
	fmt.Fprintf(w, "pipeline_failures: %d\n", r.PipelineFailures)
	fmt.Fprintln(w, "commit_messages:")
	for _, m := range r.CommitMsgs {
		fmt.Fprintln(w, m)
	}
	fmt.Fprintf(w, "mr_description_excerpt: %s\n", r.MRData.Description)
}

func printHotspots(w *bufio.Writer, allFiles []FileRecord) {
	// Count files, excluding hotspot excludes
	fileCounts := map[string]int{}
	fileBranches := map[string]map[string]bool{}
	fileTypes := map[string]map[string]int{}

	for _, fr := range allFiles {
		if hotspotExclude.MatchString(fr.File) {
			continue
		}
		fileCounts[fr.File]++
		if fileBranches[fr.File] == nil {
			fileBranches[fr.File] = map[string]bool{}
		}
		fileBranches[fr.File][fr.Branch] = true
		if fileTypes[fr.File] == nil {
			fileTypes[fr.File] = map[string]int{}
		}
		fileTypes[fr.File][fr.Type]++
	}

	// Sort by count desc
	type fileCount struct {
		File  string
		Count int
	}
	var sorted []fileCount
	for f, c := range fileCounts {
		if c >= 2 {
			sorted = append(sorted, fileCount{f, c})
		}
	}
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Count != sorted[j].Count {
			return sorted[i].Count > sorted[j].Count
		}
		return sorted[i].File < sorted[j].File
	})
	if len(sorted) > 20 {
		sorted = sorted[:20]
	}

	for _, fc := range sorted {
		branches := sortedKeys(fileBranches[fc.File])
		// Type counts sorted by count desc
		type tc struct {
			Type  string
			Count int
		}
		var tcs []tc
		for t, c := range fileTypes[fc.File] {
			tcs = append(tcs, tc{t, c})
		}
		sort.Slice(tcs, func(i, j int) bool {
			if tcs[i].Count != tcs[j].Count {
				return tcs[i].Count > tcs[j].Count
			}
			return tcs[i].Type < tcs[j].Type
		})
		var typeStr string
		for _, t := range tcs {
			typeStr += fmt.Sprintf("%s(%d) ", t.Type, t.Count)
		}
		fmt.Fprintf(w, "%d|%s|%s|%s\n", fc.Count, fc.File, strings.Join(branches, ","), typeStr)
	}
}

func printRapidFixes(w *bufio.Writer, allFiles []FileRecord, records []*MergeRecord) {
	// Index: SHA -> record
	recBySHA := map[string]*MergeRecord{}
	for _, r := range records {
		recBySHA[r.FullSHA] = r
	}

	// Index: file -> []FileRecord
	fileIndex := map[string][]FileRecord{}
	for _, fr := range allFiles {
		fileIndex[fr.File] = append(fileIndex[fr.File], fr)
	}

	seen := map[string]bool{}
	var lines []string

	for _, r := range records {
		if !bugTypeRe.MatchString(r.Type) {
			continue
		}
		bugDate := parseDate(r.Date)
		if bugDate.IsZero() {
			continue
		}
		bugEpoch := bugDate.Unix()
		sevenDaysBefore := bugEpoch - 7*86400

		// Get bug's files, excluding rapid-fix excludes
		var bugFiles []string
		for _, f := range r.ChangedFiles {
			if !rapidFixExclude.MatchString(f) {
				bugFiles = append(bugFiles, f)
			}
		}

		for _, bf := range bugFiles {
			for _, other := range fileIndex[bf] {
				if other.SHA == r.FullSHA {
					continue
				}
				otherDate := parseDate(other.Date)
				if otherDate.IsZero() {
					continue
				}
				otherEpoch := otherDate.Unix()
				if otherEpoch < sevenDaysBefore || otherEpoch > bugEpoch {
					continue
				}
				daysApart := (bugEpoch - otherEpoch) / 86400
				line := fmt.Sprintf("%s|%s|%s|%dd|%s>%s",
					r.Branch, other.Branch, bf, daysApart, r.Type, other.Type)
				if !seen[line] {
					seen[line] = true
					lines = append(lines, line)
				}
			}
		}
	}
	sort.Strings(lines)
	if len(lines) > 30 {
		lines = lines[:30]
	}
	for _, l := range lines {
		fmt.Fprintln(w, l)
	}
}

func printWeeklyDensity(w *bufio.Writer, merges []MergeCommit, typeMap map[string]string) {
	counts := map[string]int{} // "YYYY-Wxx|type" -> count
	for _, m := range merges {
		typ := typeMap[m.SHA]
		if typ == "" {
			typ = "other"
		}
		datePart := strings.Fields(m.Date)[0]
		t, err := time.Parse("2006-01-02", datePart)
		if err != nil {
			continue
		}
		year, week := t.ISOWeek()
		key := fmt.Sprintf("%d-W%02d|%s", year, week, typ)
		counts[key]++
	}

	var keys []string
	for k := range counts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Fprintf(w, "%s|%d\n", k, counts[k])
	}
}

func printCountMap(w *bufio.Writer, counts map[string]int) {
	type entry struct {
		Key   string
		Count int
	}
	var entries []entry
	for k, c := range counts {
		entries = append(entries, entry{k, c})
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Count != entries[j].Count {
			return entries[i].Count > entries[j].Count
		}
		return entries[i].Key < entries[j].Key
	})
	for _, e := range entries {
		fmt.Fprintf(w, "%7d %s\n", e.Count, e.Key)
	}
}

func printCountMapRaw(w *bufio.Writer, counts map[string]int) {
	type entry struct {
		Key   string
		Count int
	}
	var entries []entry
	for k, c := range counts {
		entries = append(entries, entry{k, c})
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Count != entries[j].Count {
			return entries[i].Count > entries[j].Count
		}
		return entries[i].Key < entries[j].Key
	})
	for _, e := range entries {
		fmt.Fprintf(w, "%7d %s\n", e.Count, e.Key)
	}
}

func printReviewMetrics(w *bufio.Writer, ttm, cycle []struct {
	Branch string
	Hours  int
}) {
	if len(ttm) > 0 {
		fmt.Fprintln(w, "time_to_merge:")
		sum := 0
		for _, e := range ttm {
			fmt.Fprintf(w, "  %s|%dh\n", e.Branch, e.Hours)
			sum += e.Hours
		}
		fmt.Fprintf(w, "avg_ttm_hours: %d\n", sum/len(ttm))
	}
	if len(cycle) > 0 {
		fmt.Fprintln(w, "cycle_time:")
		sum := 0
		for _, e := range cycle {
			fmt.Fprintf(w, "  %s|%dh\n", e.Branch, e.Hours)
			sum += e.Hours
		}
		fmt.Fprintf(w, "avg_cycle_hours: %d\n", sum/len(cycle))
	}
}

func printSizeDistribution(w *bufio.Writer, sizes []int) {
	xs, s, m, l, xl := 0, 0, 0, 0, 0
	for _, v := range sizes {
		switch {
		case v < 10:
			xs++
		case v < 50:
			s++
		case v < 200:
			m++
		case v < 500:
			l++
		default:
			xl++
		}
	}
	fmt.Fprintf(w, "xs(<10):%d\n", xs)
	fmt.Fprintf(w, "s(10-50):%d\n", s)
	fmt.Fprintf(w, "m(50-200):%d\n", m)
	fmt.Fprintf(w, "l(200-500):%d\n", l)
	fmt.Fprintf(w, "xl(500+):%d\n", xl)
}

// --- Utilities ---

func parseDate(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func sortedKeys(m map[string]bool) []string {
	var keys []string
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
