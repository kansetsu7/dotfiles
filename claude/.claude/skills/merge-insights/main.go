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
	PipelineFinal    string // status of the most recent pipeline for this MR
	WebURL           string
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
	MergedFull         string // raw merge-commit timestamp "2026-03-15 14:30:45 +0800"
	MRData
	GitData
	TTMHours   *int
	CycleHours *int
	HasTests   bool
	HasDocs    bool
	OffHours   bool   // merged on a weekend or a weekday after 18:00 (commit tz)
	IsRevert   bool   // MR is a revert of an earlier change
	RevertOf   string // quoted title of the reverted change, when detectable
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

	hotspotExclude  = regexp.MustCompile(`^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml)$`)
	rapidFixExclude = regexp.MustCompile(`^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml|config/system_config\.yml)$`)
	bugTypeRe       = regexp.MustCompile(`\b(bug|patch)\b`)
	bareDateRe      = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
)

func main() {
	// Flags: --docs selects the lean doc-suggestion output; --open sources
	// open MRs instead of merges in a range. Both are inert for the default
	// merge-insights path, which ignores docsMode/openMode entirely.
	docsMode, openMode := false, false
	var positional []string
	for _, a := range os.Args[1:] {
		switch a {
		case "--docs":
			docsMode = true
		case "--open":
			openMode = true
		default:
			positional = append(positional, a)
		}
	}

	since := "1 week ago"
	until := ""
	if len(positional) > 0 {
		since = positional[0]
	}
	// Support a bounded window written as "<start> to <end>" (e.g.
	// "2026-01-01 to 2026-05-31"). Both sides are passed to git log's
	// --since/--until, which accept absolute dates and relative expressions.
	if parts := strings.SplitN(since, " to ", 2); len(parts) == 2 {
		since = strings.TrimSpace(parts[0])
		until = strings.TrimSpace(parts[1])
		// A bare end date (YYYY-MM-DD) is inclusive of that whole day, so
		// extend it to end-of-day; git --until=<date> would otherwise stop
		// at midnight and drop merges that landed on the final day.
		if bareDateRe.MatchString(until) {
			until += " 23:59:59"
		}
	}

	token := os.Getenv("GITLAB_READONLY_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "ERROR: GITLAB_READONLY_TOKEN is not set")
		fmt.Fprintln(os.Stderr, `  load it inline before running: eval "$(gpg --quiet --decrypt ~/.config/credentials/gitlab-readonly-token.env.gpg)"`)
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
		fmt.Fprintf(os.Stderr, "ERROR: Could not resolve project ID for %q\n", projectPath)
		if wd, err := os.Getwd(); err == nil {
			fmt.Fprintf(os.Stderr, "  resolved from git remote 'origin' in %s — is this the repo you meant to analyze?\n", wd)
		}
		os.Exit(1)
	}
	glClient.projectID = projectID

	// Doc-suggestion mode: lean per-MR records (incl. changed_files) for the
	// doc-suggestions skill. Branches off before the full insights report so
	// the default output path stays untouched.
	if docsMode {
		runDocsMode(glClient, openMode, since, until, projectPath, projectID, parallel)
		return
	}

	// Collect merge commits
	merges := collectMergeCommits(since, until)
	if len(merges) == 0 {
		fmt.Println("---METADATA---")
		fmt.Println("mode: short")
		fmt.Println("total: 0")
		return
	}

	// Determine mode
	oldestDate := merges[len(merges)-1].Date
	daysSpan := computeDaysSpan(oldestDate, until)
	mode := "short"
	if daysSpan > 14 {
		mode = "long"
	}

	// Phase 1+2: concurrent collection, classification, enrichment
	records := collectAndClassify(glClient, merges, parallel)

	// Rework (first-time-quality) lookback window; overridable for teams whose
	// fixes surface on a different cadence.
	reworkWindowDays := 14
	if v := os.Getenv("MERGE_INSIGHTS_REWORK_DAYS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			reworkWindowDays = n
		}
	}

	// Baseline: the immediately-preceding equal-length window. Comparing the
	// analyzed range against it turns absolute metrics into signals ("18% —
	// but that's up from 9% last period"). Best-effort: if the range can't be
	// resolved to concrete bounds, the baseline is simply reported unavailable.
	mainAgg := computeAggregates(records, reworkWindowDays)
	var baseAgg Aggregates
	baseAvailable := false
	var baseSince, baseUntil string
	if start, end, ok := resolveWindow(since, until); ok {
		length := end.Sub(start)
		bStart := start.Add(-length)
		bEnd := start.Add(-time.Second) // exclusive of the main window's first second
		baseSince = fmtTime(bStart)
		baseUntil = fmtTime(bEnd)
		bMerges := collectMergeCommits(baseSince, baseUntil)
		if len(bMerges) > 0 {
			bRecords := collectAndClassify(glClient, bMerges, parallel)
			baseAgg = computeAggregates(bRecords, reworkWindowDays)
		}
		baseAvailable = true
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
	mrsWithPipelines, mrsFinalFailed := 0, 0
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

		// Size by total lines changed (insertions + deletions), matching the
		// common PR-size convention (GitHub diffstat, Prow size/* labels) so a
		// large rewrite or deletion-heavy change isn't undercounted.
		sizes = append(sizes, r.Insertions+r.Deletions)

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
		if r.PipelineRuns > 0 {
			mrsWithPipelines++
			if r.PipelineFinal == "failed" {
				mrsFinalFailed++
			}
		}

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
	// Headline health = share of MRs whose FINAL (most recent) pipeline failed.
	// This reflects MRs that merged with red CI, rather than counting every
	// intermediate/retry run (which fails routinely during normal iteration).
	finalFailRate := 0
	if mrsWithPipelines > 0 {
		finalFailRate = mrsFinalFailed * 100 / mrsWithPipelines
	}
	fmt.Fprintf(w, "mrs_with_pipelines:%d\n", mrsWithPipelines)
	fmt.Fprintf(w, "mrs_final_failed:%d\n", mrsFinalFailed)
	fmt.Fprintf(w, "final_failure_rate:%d%%\n", finalFailRate)
	// Run-level counts (all executions incl. retries) kept for context only.
	runFailRate := 0
	if totalPipelineRuns > 0 {
		runFailRate = totalPipelineFailures * 100 / totalPipelineRuns
	}
	fmt.Fprintf(w, "total_runs:%d\n", totalPipelineRuns)
	fmt.Fprintf(w, "total_failures:%d\n", totalPipelineFailures)
	fmt.Fprintf(w, "run_failure_rate:%d%%\n", runFailRate)

	// --- REVIEWERS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REVIEWERS---")
	printCountMapRaw(w, reviewerCounts)

	// --- SUMMARY / BASELINE ---
	// SUMMARY = the analyzed window's headline scalars; BASELINE = the same
	// scalars for the prior equal-length window. The report shows SUMMARY with a
	// delta vs BASELINE so each number reads as a trend, not an isolated figure.
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---SUMMARY---")
	emitAggregates(w, mainAgg, reworkWindowDays)

	fmt.Fprintln(w)
	fmt.Fprintln(w, "---BASELINE---")
	if baseAvailable {
		fmt.Fprintln(w, "available: yes")
		fmt.Fprintf(w, "since: %s\n", baseSince)
		fmt.Fprintf(w, "until: %s\n", baseUntil)
		emitAggregates(w, baseAgg, reworkWindowDays)
	} else {
		fmt.Fprintln(w, "available: no")
	}

	// --- REWORK (first-time-quality) ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REWORK---")
	pairs := reworkPairs(records, reworkWindowDays)
	fmt.Fprintf(w, "rate: %d%% (%d/%d feature MRs re-fixed within %dd)\n",
		mainAgg.ReworkRate, mainAgg.ReworkMisses, mainAgg.ReworkFeatureMRs, reworkWindowDays)
	printReworkPairs(w, pairs)

	// --- REVERTS ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REVERTS---")
	printReverts(w, records)

	// --- TIMING ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---TIMING---")
	printTiming(w, records, mainAgg)

	// --- REVIEW-RISK ---
	// Possible rubber-stamps: large diffs merged suspiciously fast. Derived from
	// data already collected (no extra API); a proxy, not proof.
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---REVIEW-RISK---")
	printReviewRisk(w, records)

	// --- METADATA ---
	fmt.Fprintln(w)
	fmt.Fprintln(w, "---METADATA---")
	fmt.Fprintf(w, "mode: %s\n", mode)
	fmt.Fprintf(w, "total: %d\n", len(records))
	fmt.Fprintf(w, "days_span: %d\n", daysSpan)
	fmt.Fprintf(w, "since: %s\n", since)
	if until != "" {
		fmt.Fprintf(w, "until: %s\n", until)
	}
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

func collectMergeCommits(since, until string) []MergeCommit {
	args := []string{"log", "master", "--merges", "--first-parent",
		"--since=" + since, "--format=%H|%ai|%s"}
	if until != "" {
		args = append(args, "--until="+until)
	}
	out, err := exec.Command("git", args...).Output()
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

func computeDaysSpan(oldestDateStr, until string) int {
	datePart := strings.Fields(oldestDateStr)[0]
	t, err := time.Parse("2006-01-02", datePart)
	if err != nil {
		return 0
	}
	// For a bounded window, measure to the window's end rather than to now
	// so short historical ranges aren't misclassified as long.
	end := time.Now()
	if until != "" {
		if u, err := time.Parse("2006-01-02", strings.Fields(until)[0]); err == nil {
			end = u
		}
	}
	return int(end.Sub(t).Hours() / 24)
}

// --- Phase 1: Concurrent collection per merge ---

func collectOneMerge(gl *GitLabClient, mc MergeCommit) *MergeRecord {
	matches := branchRe.FindStringSubmatch(mc.Message)
	if matches == nil {
		return nil
	}
	branch := matches[1]

	r := &MergeRecord{
		SHA12:      mc.SHA[:12],
		FullSHA:    mc.SHA,
		Date:       strings.Fields(mc.Date)[0],
		MergedFull: mc.Date,
		Branch:     branch,
	}

	// GitLab MR API
	encodedBranch := url.QueryEscape(branch)
	resp, err := gl.get(fmt.Sprintf("/projects/%d/merge_requests?state=merged&source_branch=%s&per_page=1",
		gl.projectID, encodedBranch))
	if err == nil {
		defer resp.Body.Close()
		var mrs []struct {
			IID    int    `json:"iid"`
			Title  string `json:"title"`
			Author struct {
				Name string `json:"name"`
			} `json:"author"`
			Description string `json:"description"`
			CreatedAt   string `json:"created_at"`
			MergedAt    string `json:"merged_at"`
			WebURL      string `json:"web_url"`
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
			r.MRData.WebURL = mr.WebURL
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
				ID     int    `json:"id"`
				Status string `json:"status"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&pipelines); err == nil {
				r.MRData.PipelineRuns = len(pipelines)
				maxID := -1
				for _, p := range pipelines {
					if p.Status == "failed" {
						r.MRData.PipelineFailures++
					}
					// Track the most recent pipeline (highest id) as the final one.
					if p.ID > maxID {
						maxID = p.ID
						r.MRData.PipelineFinal = p.Status
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
	offHours := "no"
	if r.OffHours {
		offHours = "yes"
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
	fmt.Fprintf(w, "off_hours: %s\n", offHours)
	if r.IsRevert {
		fmt.Fprintf(w, "revert: yes (of %q)\n", r.RevertOf)
	}
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
		hours := make([]int, 0, len(ttm))
		for _, e := range ttm {
			fmt.Fprintf(w, "  %s|%dh\n", e.Branch, e.Hours)
			sum += e.Hours
			hours = append(hours, e.Hours)
		}
		// Median is the typical value; the mean is reported too but is skewed
		// upward by a few long-lived branches, so prefer the median in prose.
		fmt.Fprintf(w, "median_ttm_hours: %d\n", median(hours))
		fmt.Fprintf(w, "avg_ttm_hours: %d\n", sum/len(ttm))
	}
	if len(cycle) > 0 {
		fmt.Fprintln(w, "cycle_time:")
		sum := 0
		hours := make([]int, 0, len(cycle))
		for _, e := range cycle {
			fmt.Fprintf(w, "  %s|%dh\n", e.Branch, e.Hours)
			sum += e.Hours
			hours = append(hours, e.Hours)
		}
		fmt.Fprintf(w, "median_cycle_hours: %d\n", median(hours))
		fmt.Fprintf(w, "avg_cycle_hours: %d\n", sum/len(cycle))
	}
}

// median returns the median of a non-empty slice (average of the two middle
// values for even length). Sorts a copy so the caller's order is preserved.
func median(v []int) int {
	if len(v) == 0 {
		return 0
	}
	s := append([]int(nil), v...)
	sort.Ints(s)
	n := len(s)
	if n%2 == 1 {
		return s[n/2]
	}
	return (s[n/2-1] + s[n/2]) / 2
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

// --- Collection helper (shared by the main path and the baseline pass) ---

func collectAndClassify(gl *GitLabClient, merges []MergeCommit, parallel int) []*MergeRecord {
	results := make([]*MergeRecord, len(merges))
	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for i, m := range merges {
		wg.Add(1)
		go func(idx int, mc MergeCommit) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			results[idx] = collectOneMerge(gl, mc)
		}(i, m)
	}
	wg.Wait()

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
		r.OffHours = computeOffHours(r.MergedFull)
		r.IsRevert, r.RevertOf = detectRevert(r.Branch, r.MRData.Title)
		records = append(records, r)
	}
	return records
}

// computeOffHours flags a merge that landed on a weekend or on a weekday after
// 18:00, evaluated in the commit's own timezone (the raw offset is preserved by
// parseGitDate), so "after hours" means after hours for whoever merged it.
func computeOffHours(raw string) bool {
	t := parseGitDate(raw)
	if t.IsZero() {
		return false
	}
	switch t.Weekday() {
	case time.Saturday, time.Sunday:
		return true
	}
	return t.Hour() >= 18
}

// detectRevert recognizes reverts from the GitLab "Revert" affordance: the
// generated branch is `revert-<sha>` and the title is `Revert "<original>"`.
// The quoted original title, when present, is returned so the report can name
// what was rolled back.
func detectRevert(branch, title string) (bool, string) {
	isRevert := strings.HasPrefix(strings.ToLower(title), "revert ") ||
		strings.HasPrefix(strings.ToLower(title), "revert-") ||
		strings.HasPrefix(branch, "revert-")
	if !isRevert {
		return false, ""
	}
	if i := strings.Index(title, "\""); i >= 0 {
		if j := strings.Index(title[i+1:], "\""); j >= 0 {
			return true, title[i+1 : i+1+j]
		}
	}
	return true, ""
}

// --- Aggregates (headline scalars, computed for both the main and baseline windows) ---

type Aggregates struct {
	Total            int
	BugCount         int // type=="bug" only (excludes patch), matching the Bug ratio convention
	MedianTTM        int
	MedianCycle      int
	MedianSize       int
	WithTests        int
	TestRatio        int
	MRsWithPipelines int
	FinalFailed      int
	FinalFailRate    int
	ReworkFeatureMRs int
	ReworkMisses     int
	ReworkRate       int
	OffHoursMerges   int
	OffHoursRate     int
	Reverts          int
}

func computeAggregates(records []*MergeRecord, windowDays int) Aggregates {
	var a Aggregates
	a.Total = len(records)
	var ttm, cycle, sizes []int
	featureMRs := 0
	for _, r := range records {
		if r.Type == "bug" {
			a.BugCount++
		}
		if r.Type == "feature" {
			featureMRs++
		}
		if r.TTMHours != nil {
			ttm = append(ttm, *r.TTMHours)
		}
		if r.CycleHours != nil {
			cycle = append(cycle, *r.CycleHours)
		}
		sizes = append(sizes, r.Insertions+r.Deletions)
		if r.HasTests {
			a.WithTests++
		}
		if r.PipelineRuns > 0 {
			a.MRsWithPipelines++
			if r.PipelineFinal == "failed" {
				a.FinalFailed++
			}
		}
		if r.OffHours {
			a.OffHoursMerges++
		}
		if r.IsRevert {
			a.Reverts++
		}
	}
	a.MedianTTM = median(ttm)
	a.MedianCycle = median(cycle)
	a.MedianSize = median(sizes)
	a.TestRatio = pct(a.WithTests, a.Total)
	a.OffHoursRate = pct(a.OffHoursMerges, a.Total)
	a.FinalFailRate = pct(a.FinalFailed, a.MRsWithPipelines)

	// Rework: distinct feature MRs whose files a fix re-touched within the window.
	missSet := map[string]bool{}
	for _, p := range reworkPairs(records, windowDays) {
		missSet[p.FeatureBranch] = true
	}
	a.ReworkFeatureMRs = featureMRs
	a.ReworkMisses = len(missSet)
	a.ReworkRate = pct(len(missSet), featureMRs)
	return a
}

func emitAggregates(w *bufio.Writer, a Aggregates, windowDays int) {
	fmt.Fprintf(w, "total: %d\n", a.Total)
	fmt.Fprintf(w, "bug_count: %d\n", a.BugCount)
	fmt.Fprintf(w, "bug_ratio: %d%%\n", pct(a.BugCount, a.Total))
	fmt.Fprintf(w, "median_ttm_hours: %d\n", a.MedianTTM)
	fmt.Fprintf(w, "median_cycle_hours: %d\n", a.MedianCycle)
	fmt.Fprintf(w, "median_size_lines: %d\n", a.MedianSize)
	fmt.Fprintf(w, "test_ratio: %d%%\n", a.TestRatio)
	fmt.Fprintf(w, "final_failure_rate: %d%%\n", a.FinalFailRate)
	fmt.Fprintf(w, "rework_rate: %d%% (%d/%d feature MRs within %dd)\n",
		a.ReworkRate, a.ReworkMisses, a.ReworkFeatureMRs, windowDays)
	fmt.Fprintf(w, "off_hours_rate: %d%% (%d/%d)\n", a.OffHoursRate, a.OffHoursMerges, a.Total)
	fmt.Fprintf(w, "reverts: %d\n", a.Reverts)
}

func pct(n, d int) int {
	if d == 0 {
		return 0
	}
	return n * 100 / d
}

// --- Rework (first-time-quality) ---

type ReworkPair struct {
	File          string
	FeatureBranch string
	FeatureIID    int
	FixBranch     string
	FixIID        int
	DaysApart     int
}

// reworkPairs finds files that shipped in a feature MR and were re-touched by a
// bug/patch MR within windowDays — the code-level signal that a feature shipped
// not-quite-right. Schema/locale churn is excluded (same excludes as rapid-fix)
// since those aren't first-time-quality misses. Same boundary caveat as
// rapid-fix: a feature merged just before the window is invisible here.
func reworkPairs(records []*MergeRecord, windowDays int) []ReworkPair {
	fixIndex := map[string][]*MergeRecord{}
	for _, r := range records {
		if !bugTypeRe.MatchString(r.Type) {
			continue
		}
		for _, f := range r.ChangedFiles {
			if rapidFixExclude.MatchString(f) {
				continue
			}
			fixIndex[f] = append(fixIndex[f], r)
		}
	}

	seen := map[string]bool{}
	var pairs []ReworkPair
	for _, r := range records {
		if r.Type != "feature" {
			continue
		}
		fDate := parseDate(r.Date)
		if fDate.IsZero() {
			continue
		}
		for _, f := range r.ChangedFiles {
			if rapidFixExclude.MatchString(f) {
				continue
			}
			for _, fix := range fixIndex[f] {
				if fix.FullSHA == r.FullSHA {
					continue
				}
				xDate := parseDate(fix.Date)
				if xDate.IsZero() {
					continue
				}
				days := int(xDate.Sub(fDate).Hours() / 24)
				if days < 0 || days > windowDays {
					continue
				}
				key := r.FullSHA + "|" + fix.FullSHA + "|" + f
				if seen[key] {
					continue
				}
				seen[key] = true
				pairs = append(pairs, ReworkPair{
					File: f, FeatureBranch: r.Branch, FeatureIID: r.MRData.IID,
					FixBranch: fix.Branch, FixIID: fix.MRData.IID, DaysApart: days,
				})
			}
		}
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].DaysApart != pairs[j].DaysApart {
			return pairs[i].DaysApart < pairs[j].DaysApart
		}
		return pairs[i].File < pairs[j].File
	})
	if len(pairs) > 40 {
		pairs = pairs[:40]
	}
	return pairs
}

func printReworkPairs(w *bufio.Writer, pairs []ReworkPair) {
	for _, p := range pairs {
		fmt.Fprintf(w, "%s|%s !%s|%s !%s|%dd\n",
			p.File, p.FeatureBranch, iidStr(p.FeatureIID),
			p.FixBranch, iidStr(p.FixIID), p.DaysApart)
	}
}

func printReverts(w *bufio.Writer, records []*MergeRecord) {
	for _, r := range records {
		if !r.IsRevert {
			continue
		}
		of := r.RevertOf
		if of == "" {
			of = "?"
		}
		fmt.Fprintf(w, "%s !%s|%s|reverts: %q\n", r.Branch, iidStr(r.MRData.IID), r.Date, of)
	}
}

func printTiming(w *bufio.Writer, records []*MergeRecord, a Aggregates) {
	fmt.Fprintf(w, "off_hours_merges: %d\n", a.OffHoursMerges)
	fmt.Fprintf(w, "off_hours_rate: %d%%\n", a.OffHoursRate)
	fmt.Fprintln(w, "mrs:")
	n := 0
	for _, r := range records {
		if !r.OffHours {
			continue
		}
		if n >= 20 {
			break
		}
		fmt.Fprintf(w, "  %s !%s|%s\n", r.Branch, iidStr(r.MRData.IID), r.MergedFull)
		n++
	}
}

// printReviewRisk lists large diffs that merged within an hour — a proxy for a
// rubber-stamped review. Uses only already-collected fields; treat as a prompt
// to look, not a verdict.
func printReviewRisk(w *bufio.Writer, records []*MergeRecord) {
	for _, r := range records {
		lines := r.Insertions + r.Deletions
		if lines <= 200 || r.TTMHours == nil || *r.TTMHours > 1 {
			continue
		}
		reviewers := "?"
		if len(r.MRData.Assignees) > 0 {
			reviewers = strings.Join(r.MRData.Assignees, ",")
		}
		fmt.Fprintf(w, "%s !%s|%d lines|%dh|reviewers: %s\n",
			r.Branch, iidStr(r.MRData.IID), lines, *r.TTMHours, reviewers)
	}
}

func iidStr(iid int) string {
	if iid > 0 {
		return strconv.Itoa(iid)
	}
	return "?"
}

// --- Window resolution (for the baseline pass) ---

// resolveWindow turns the analyzed range's since/until into concrete start/end
// times so the immediately-preceding equal-length window can be derived. It
// handles the documented argument forms (absolute dates, "since <date>", "this
// week", "last N weeks/days/months", "N <unit> ago"). Unrecognized forms return
// ok=false and the caller simply omits the baseline.
func resolveWindow(since, until string) (start, end time.Time, ok bool) {
	now := time.Now()
	end = now
	if until != "" {
		if t, ok2 := parseFlexDate(until); ok2 {
			end = t
		}
	}

	s := strings.TrimSpace(strings.ToLower(since))
	s = strings.TrimPrefix(s, "since ")

	if t, ok2 := parseFlexDate(s); ok2 {
		return t, end, true
	}

	switch s {
	case "today":
		return truncDay(now), end, true
	case "yesterday":
		return truncDay(now).AddDate(0, 0, -1), end, true
	case "this week", "last week":
		// Approximate a week window; exact weekday boundary isn't needed for a
		// same-length baseline offset.
		wk := truncDay(now).AddDate(0, 0, -7)
		return wk, end, true
	}

	// "last N units", "past N units", "N units ago", "N units"
	if m := regexp.MustCompile(`(\d+)\s+(day|week|month|year)s?`).FindStringSubmatch(s); m != nil {
		n, _ := strconv.Atoi(m[1])
		switch m[2] {
		case "day":
			return end.AddDate(0, 0, -n), end, true
		case "week":
			return end.AddDate(0, 0, -7*n), end, true
		case "month":
			return end.AddDate(0, -n, 0), end, true
		case "year":
			return end.AddDate(-n, 0, 0), end, true
		}
	}
	return time.Time{}, time.Time{}, false
}

// parseFlexDate accepts "2006-01-02" or "2006-01-02 15:04:05" in local time.
func parseFlexDate(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", s, time.Local); err == nil {
		return t, true
	}
	if t, err := time.ParseInLocation("2006-01-02", s, time.Local); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func truncDay(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
}

func fmtTime(t time.Time) string {
	return t.Format("2006-01-02 15:04:05")
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

// --- Doc-suggestion mode ---
//
// Emits a lean stream of ---MERGE--- records (each including a changed_files:
// block) for the doc-suggestions skill, then a ---METADATA--- footer. The heavy
// aggregate sections (hotspots, rapid-fix, etc.) are intentionally omitted — the
// skill only needs per-MR files + context to reason about documentation gaps.

func runDocsMode(gl *GitLabClient, openMode bool, since, until, projectPath string, projectID, parallel int) {
	var records []*MergeRecord

	if openMode {
		records = collectOpenMRRecords(gl, parallel)
	} else {
		merges := collectMergeCommits(since, until)
		results := make([]*MergeRecord, len(merges))
		sem := make(chan struct{}, parallel)
		var wg sync.WaitGroup
		for i, m := range merges {
			wg.Add(1)
			go func(idx int, mc MergeCommit) {
				defer wg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()
				results[idx] = collectOneMerge(gl, mc)
			}(i, m)
		}
		wg.Wait()
		for _, r := range results {
			if r == nil {
				continue
			}
			r.Type = classifyType(r.Branch, r.CommitMsgs, r.MRData.Title)
			r.HasDocs = hasDocFiles(r.ChangedFiles)
			records = append(records, r)
		}
	}

	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()

	for _, r := range records {
		printDocRecord(w, r)
	}

	fmt.Fprintln(w)
	fmt.Fprintln(w, "---METADATA---")
	mode := "docs-merged"
	if openMode {
		mode = "docs-open"
	}
	fmt.Fprintf(w, "mode: %s\n", mode)
	fmt.Fprintf(w, "total: %d\n", len(records))
	if !openMode {
		fmt.Fprintf(w, "since: %s\n", since)
		if until != "" {
			fmt.Fprintf(w, "until: %s\n", until)
		}
	}
	fmt.Fprintf(w, "project: %s (ID: %d)\n", projectPath, projectID)
}

// collectOpenMRRecords lists every open MR in the project (paginated) and
// concurrently enriches each with its changed files.
func collectOpenMRRecords(gl *GitLabClient, parallel int) []*MergeRecord {
	var records []*MergeRecord

	for page := 1; ; page++ {
		resp, err := gl.get(fmt.Sprintf(
			"/projects/%d/merge_requests?state=opened&per_page=100&page=%d&order_by=created_at&sort=desc",
			gl.projectID, page))
		if err != nil {
			break
		}
		var mrs []struct {
			IID    int    `json:"iid"`
			Title  string `json:"title"`
			Author struct {
				Name string `json:"name"`
			} `json:"author"`
			Description  string `json:"description"`
			CreatedAt    string `json:"created_at"`
			SourceBranch string `json:"source_branch"`
			WebURL       string `json:"web_url"`
		}
		derr := json.NewDecoder(resp.Body).Decode(&mrs)
		resp.Body.Close()
		if derr != nil || len(mrs) == 0 {
			break
		}
		for _, mr := range mrs {
			r := &MergeRecord{Branch: mr.SourceBranch}
			r.MRData.IID = mr.IID
			r.MRData.Title = mr.Title
			r.MRData.Author = mr.Author.Name
			desc := strings.ReplaceAll(mr.Description, "\n", " ")
			if len(desc) > 200 {
				desc = desc[:200]
			}
			r.MRData.Description = desc
			r.MRData.CreatedAt = parseGitLabTime(mr.CreatedAt)
			r.MRData.WebURL = mr.WebURL
			if !r.MRData.CreatedAt.IsZero() {
				r.Date = r.MRData.CreatedAt.Format("2006-01-02")
			}
			records = append(records, r)
		}
		if len(mrs) < 100 {
			break
		}
	}

	// Enrich with changed files concurrently.
	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for _, r := range records {
		wg.Add(1)
		go func(rec *MergeRecord) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			rec.GitData.ChangedFiles = collectOpenMRChangedFiles(gl, rec.MRData.IID)
			rec.Type = classifyType(rec.Branch, nil, rec.MRData.Title)
			rec.HasDocs = hasDocFiles(rec.GitData.ChangedFiles)
		}(r)
	}
	wg.Wait()
	return records
}

// collectOpenMRChangedFiles returns the paths an open MR touches, via the
// merge_requests/:iid/changes endpoint (returns all changes in one payload, no
// pagination needed — preferred over /diffs for completeness on large MRs).
func collectOpenMRChangedFiles(gl *GitLabClient, iid int) []string {
	resp, err := gl.get(fmt.Sprintf("/projects/%d/merge_requests/%d/changes", gl.projectID, iid))
	if err != nil {
		return nil
	}
	defer resp.Body.Close()

	var result struct {
		Changes []struct {
			OldPath     string `json:"old_path"`
			NewPath     string `json:"new_path"`
			DeletedFile bool   `json:"deleted_file"`
		} `json:"changes"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil
	}
	var files []string
	for _, c := range result.Changes {
		p := c.NewPath
		if c.DeletedFile && c.OldPath != "" {
			p = c.OldPath
		}
		if p != "" {
			files = append(files, p)
		}
	}
	return files
}

func printDocRecord(w *bufio.Writer, r *MergeRecord) {
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
	hasDocs := "no"
	if r.HasDocs {
		hasDocs = "yes"
	}

	fmt.Fprintln(w, "---MERGE---")
	if r.SHA12 != "" {
		fmt.Fprintf(w, "sha: %s\n", r.SHA12)
	}
	fmt.Fprintf(w, "date: %s\n", r.Date)
	fmt.Fprintf(w, "branch: %s\n", r.Branch)
	fmt.Fprintf(w, "type: %s\n", r.Type)
	fmt.Fprintf(w, "mr_iid: %s\n", iid)
	fmt.Fprintf(w, "mr_title: %s\n", title)
	fmt.Fprintf(w, "author: %s\n", author)
	if r.MRData.WebURL != "" {
		fmt.Fprintf(w, "web_url: %s\n", r.MRData.WebURL)
	}
	fmt.Fprintf(w, "has_docs: %s\n", hasDocs)
	fmt.Fprintf(w, "files_changed: %d\n", len(r.ChangedFiles))
	fmt.Fprintln(w, "changed_files:")
	for _, f := range r.ChangedFiles {
		fmt.Fprintln(w, f)
	}
	fmt.Fprintf(w, "mr_description_excerpt: %s\n", r.MRData.Description)
}
