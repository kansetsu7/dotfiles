package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// --- fixtures ---------------------------------------------------------------

// writeSession writes a minimal but structurally faithful transcript.
func writeSession(t *testing.T, dir, name, cwd, sessName string, msgs ...[2]string) string {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	var b strings.Builder
	b.WriteString(`{"type":"session","version":3,"id":"x","timestamp":"2026-08-20T10:00:00.000Z","cwd":"` + cwd + "\"}\n")
	b.WriteString(`{"type":"model_change","modelId":"claude-opus-5"}` + "\n")
	if sessName != "" {
		b.WriteString(`{"type":"session_info","name":"` + sessName + "\"}\n")
	}
	for _, m := range msgs {
		b.WriteString(`{"type":"message","message":{"role":"` + m[0] +
			`","content":[{"type":"text","text":"` + m[1] + `"}]}}` + "\n")
	}
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

func fixtureRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	writeSession(t, filepath.Join(root, "--proj-nerv--"), "a.jsonl",
		"/proj/nerv_hk", "payment-fix",
		[2]string{"user", "why does the payment return no-op?"},
		[2]string{"assistant", "because save! is a no-op"})
	writeSession(t, filepath.Join(root, "--proj-nerv--"), "b.jsonl",
		"/proj/nerv_ck", "erb-comment",
		[2]string{"user", "comment this ERB block"})
	writeSession(t, filepath.Join(root, "--proj-nerv_hk-lilith--"), "c.jsonl",
		"/proj/nerv_hk/lilith", "lilith-blank",
		[2]string{"user", "is_empty should be blank"})
	writeSession(t, filepath.Join(root, "--root-.dotfiles--"), "d.jsonl",
		"/root/.dotfiles", "stow-things",
		[2]string{"user", "stow the payment package"})
	// tool output must never be searched: it is the bulk of a transcript and
	// swamps the conversation
	writeSession(t, filepath.Join(root, "--proj-nerv--"), "e.jsonl",
		"/proj/nerv_sg", "tool-only",
		[2]string{"toolResult", "grep found payment in 12 files"})
	return root
}

func withEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	for k, v := range kv {
		t.Setenv(k, v)
	}
}

// --- unit tests -------------------------------------------------------------

func TestIsNervBoundaries(t *testing.T) {
	withEnv(t, map[string]string{"PROJECT_PATH": "/proj", "NERV_PREFIX": "nerv_"})
	roots := nervRoots()

	cases := []struct {
		cwd  string
		want bool
	}{
		{"/proj/nerv_hk", true},
		{"/proj/nerv_hk/lilith", true}, // subdirectory of a worktree
		{"/proj/nerv_ave_ck", true},
		{"/proj/nerv_hk_scratch", false}, // prefix must not leak past the boundary
		{"/proj/nervcop", false},         // shares the "nerv" substring only
		{"/proj/amoeba", false},
		{"/root/.dotfiles", false},
	}
	for _, c := range cases {
		if got := isNerv(c.cwd, roots); got != c.want {
			t.Errorf("isNerv(%q) = %v, want %v", c.cwd, got, c.want)
		}
	}
}

// On mac NERV_PREFIX is empty and PROJECT_PATH is ~/proj, so a hardcoded
// "nerv" match would silently find nothing.
func TestNervRootsMacLayout(t *testing.T) {
	withEnv(t, map[string]string{"PROJECT_PATH": "/Users/me/proj", "NERV_PREFIX": ""})
	roots := nervRoots()
	if !isNerv("/Users/me/proj/hk", roots) {
		t.Errorf("mac layout: /Users/me/proj/hk should be a Nerv worktree, roots=%v", roots)
	}
	if isNerv("/proj/nerv_hk", roots) {
		t.Error("mac layout should not match the docker paths")
	}
}

func TestLoadSessions(t *testing.T) {
	root := fixtureRoot(t)
	sessions, err := LoadSessions(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(sessions) != 5 {
		t.Fatalf("got %d sessions, want 5", len(sessions))
	}
	byName := map[string]Session{}
	for _, s := range sessions {
		byName[s.Name] = s
	}
	if got := byName["payment-fix"].Tree; got != "nerv_hk" {
		t.Errorf("Tree = %q, want nerv_hk", got)
	}
	// a subdirectory should be reported relative to $PROJECT_PATH, not as a
	// bare, ambiguous "lilith"
	if got := byName["lilith-blank"].Tree; got != "nerv_hk/lilith" {
		t.Errorf("Tree = %q, want nerv_hk/lilith", got)
	}
	if n := len(byName["payment-fix"].Messages); n != 2 {
		t.Errorf("got %d messages, want 2", n)
	}
}

func TestToolOutputIsNeverLoaded(t *testing.T) {
	root := fixtureRoot(t)
	sessions, _ := LoadSessions(root)
	var toolOnly Session
	for _, s := range sessions {
		if s.Name == "tool-only" {
			toolOnly = s
		}
	}
	if n := len(toolOnly.Messages); n != 0 {
		t.Errorf("tool output should be dropped at parse time, got %d messages", n)
	}
	if hits := toolOnly.Search("payment"); len(hits) != 0 {
		t.Errorf("tool output must never match, got %d hits", len(hits))
	}
}

func TestSearchCaseInsensitive(t *testing.T) {
	root := fixtureRoot(t)
	sessions, _ := LoadSessions(root)
	for _, s := range sessions {
		if s.Name != "payment-fix" {
			continue
		}
		if hits := s.Search("PAYMENT"); len(hits) != 1 {
			t.Errorf("case-insensitive search got %d hits, want 1", len(hits))
		}
	}
}

func TestHighlightPreservesCase(t *testing.T) {
	out := highlight("The Payment Return", "payment")
	if !strings.Contains(out, "Payment") {
		t.Errorf("highlight destroyed original casing: %q", out)
	}
}

func TestSnippetCentresOnMatch(t *testing.T) {
	body := strings.Repeat("x", 500) + "NEEDLE" + strings.Repeat("y", 500)
	got := snippet(body, "needle", 120)
	if !strings.Contains(got, "NEEDLE") {
		t.Errorf("snippet lost the match: %q", got)
	}
	if len(got) > 140 {
		t.Errorf("snippet too long: %d bytes", len(got))
	}
}

func TestTruncRuneSafe(t *testing.T) {
	if got := trunc("日本語テキスト", 4); len([]rune(got)) != 4 {
		t.Errorf("trunc = %q (%d runes), want 4 runes", got, len([]rune(got)))
	}
}

// --- model / TUI behaviour --------------------------------------------------

func key(s string) tea.KeyPressMsg {
	switch s {
	case "tab":
		return tea.KeyPressMsg{Code: tea.KeyTab}
	case "enter":
		return tea.KeyPressMsg{Code: tea.KeyEnter}
	case "down":
		return tea.KeyPressMsg{Code: tea.KeyDown}
	case "ctrl+d":
		return tea.KeyPressMsg{Code: 'd', Mod: tea.ModCtrl}
	}
	return tea.KeyPressMsg{Code: rune(s[0]), Text: s}
}

func typeString(m tea.Model, s string) tea.Model {
	for _, r := range s {
		m, _ = m.Update(tea.KeyPressMsg{Code: r, Text: string(r)})
	}
	return m
}

func newTestModel(t *testing.T) tea.Model {
	t.Helper()
	withEnv(t, map[string]string{"PROJECT_PATH": "/proj", "NERV_PREFIX": "nerv_"})
	sessions, err := LoadSessions(fixtureRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	var m tea.Model = initialModel(sessions, "", true)
	m, _ = m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	return m
}

func TestModelFiltersToNervByDefault(t *testing.T) {
	m := newTestModel(t)
	// 4 Nerv sessions in the fixture; the dotfiles one must be excluded
	if got := len(m.(model).results); got != 4 {
		t.Fatalf("nerv scope: got %d results, want 4", got)
	}
	for _, r := range m.(model).results {
		if strings.Contains(r.Session.Tree, "dotfiles") {
			t.Error("dotfiles session leaked into nerv scope")
		}
	}
}

func TestModelTypingFilters(t *testing.T) {
	m := typeString(newTestModel(t), "payment")
	res := m.(model).results
	if len(res) != 1 {
		t.Fatalf("query 'payment': got %d results, want 1 (%v)", len(res), names(res))
	}
	if res[0].Session.Name != "payment-fix" {
		t.Errorf("got %q, want payment-fix", res[0].Session.Name)
	}
}

func TestModelTabWidensScope(t *testing.T) {
	m := typeString(newTestModel(t), "payment")
	if got := len(m.(model).results); got != 1 {
		t.Fatalf("precondition: got %d, want 1", got)
	}
	m, _ = m.Update(key("tab")) // nerv -> all
	// now the /root/.dotfiles session ("stow the payment package") joins
	if got := len(m.(model).results); got != 2 {
		t.Errorf("after tab: got %d results, want 2 (%v)", got, names(m.(model).results))
	}
}

// Enter must carry the recorded cwd, not just the transcript path: resuming
// in the wrong worktree is the exact failure this tool exists to avoid.
func TestModelEnterSelectsSessionWithCWD(t *testing.T) {
	m := typeString(newTestModel(t), "payment")
	m, _ = m.Update(key("enter"))
	got := m.(model).chosen
	if got == nil {
		t.Fatal("chosen = nil, want the payment-fix session")
	}
	if !strings.HasSuffix(got.Path, "a.jsonl") {
		t.Errorf("Path = %q, want the payment-fix transcript", got.Path)
	}
	if got.CWD != "/proj/nerv_hk" {
		t.Errorf("CWD = %q, want /proj/nerv_hk", got.CWD)
	}
}

func TestModelNoMatchesIsSafe(t *testing.T) {
	m := typeString(newTestModel(t), "zzzznope")
	if got := len(m.(model).results); got != 0 {
		t.Fatalf("got %d results, want 0", got)
	}
	// navigating and selecting an empty list must not panic
	m, _ = m.Update(key("down"))
	m, _ = m.Update(key("enter"))
	if got := m.(model).chosen; got != nil {
		t.Errorf("chosen = %v, want nil", got)
	}
	_ = m.View()
}

func TestViewRendersWithoutPanic(t *testing.T) {
	m := typeString(newTestModel(t), "pay")
	v := m.View()
	if !strings.Contains(v.Content, "pi-hist") {
		t.Error("title missing from view")
	}
	if !v.AltScreen {
		t.Error("expected alt screen")
	}
}

// --- delete ------------------------------------------------------------------

// newTestModelAt is newTestModel but exposes the fixture root, so delete tests
// can assert against the filesystem.
func newTestModelAt(t *testing.T) (tea.Model, string) {
	t.Helper()
	withEnv(t, map[string]string{"PROJECT_PATH": "/proj", "NERV_PREFIX": "nerv_"})
	root := fixtureRoot(t)
	sessions, err := LoadSessions(root)
	if err != nil {
		t.Fatal(err)
	}
	var m tea.Model = initialModel(sessions, "", true)
	m, _ = m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	return m, root
}

func TestDeleteRequiresConfirmation(t *testing.T) {
	m, _ := newTestModelAt(t)
	before := len(m.(model).results)
	target := m.(model).results[0].Session.Path

	m, _ = m.Update(key("ctrl+d"))
	if m.(model).pending == nil {
		t.Fatal("ctrl+d should arm a confirmation")
	}
	// nothing removed yet
	if _, err := os.Stat(target); err != nil {
		t.Fatalf("file deleted before confirmation: %v", err)
	}
	if got := len(m.(model).results); got != before {
		t.Errorf("result count changed before confirmation: %d -> %d", before, got)
	}
}

func TestDeleteConfirmedRemovesFile(t *testing.T) {
	m, _ := newTestModelAt(t)
	before := len(m.(model).results)
	target := m.(model).results[0].Session.Path

	m, _ = m.Update(key("ctrl+d"))
	m, _ = m.Update(key("y"))

	if _, err := os.Stat(target); !os.IsNotExist(err) {
		t.Errorf("transcript still on disk: %v", err)
	}
	mm := m.(model)
	if got := len(mm.results); got != before-1 {
		t.Errorf("results = %d, want %d", got, before-1)
	}
	if mm.pending != nil {
		t.Error("confirmation should be cleared after deleting")
	}
	for _, s := range mm.all {
		if s.Path == target {
			t.Error("deleted session still present in the loaded set")
		}
	}
}

func TestDeleteCancelledKeepsFile(t *testing.T) {
	m, _ := newTestModelAt(t)
	before := len(m.(model).results)
	target := m.(model).results[0].Session.Path

	m, _ = m.Update(key("ctrl+d"))
	m, _ = m.Update(key("n"))

	if _, err := os.Stat(target); err != nil {
		t.Errorf("cancelling deleted the file anyway: %v", err)
	}
	if got := len(m.(model).results); got != before {
		t.Errorf("results = %d, want %d", got, before)
	}
	if m.(model).pending != nil {
		t.Error("confirmation should be cleared after cancelling")
	}
}

// The search input is always focused, so the confirmation must swallow every
// key: a stray "n" that reached the input would silently change the result set
// under the cursor while the user believed they were answering a prompt.
func TestConfirmationSwallowsKeys(t *testing.T) {
	m, _ := newTestModelAt(t)
	m, _ = m.Update(key("ctrl+d"))
	m, _ = m.Update(key("n"))
	if got := m.(model).input.Value(); got != "" {
		t.Errorf("query = %q, want empty — the prompt leaked a keystroke", got)
	}
}

// Only "y" may destroy a file; any other answer cancels.
func TestOnlyYConfirms(t *testing.T) {
	for _, k := range []string{"n", "q", "z", "Y"} {
		m, _ := newTestModelAt(t)
		target := m.(model).results[0].Session.Path
		m, _ = m.Update(key("ctrl+d"))
		m, _ = m.Update(key(k))
		_, err := os.Stat(target)
		if k == "y" {
			continue
		}
		if err != nil {
			t.Errorf("key %q deleted the transcript, want cancel", k)
		}
	}
}

func TestDeleteWithNoResultsIsSafe(t *testing.T) {
	m := typeString(newTestModel(t), "zzzznope")
	m, _ = m.Update(key("ctrl+d"))
	if m.(model).pending != nil {
		t.Error("nothing selected, so nothing should be armed")
	}
	m, _ = m.Update(key("y"))
	_ = m.View()
}

// Deleting the last row must leave the cursor on a valid entry.
func TestDeleteLastRowKeepsCursorValid(t *testing.T) {
	m, _ := newTestModelAt(t)
	for range m.(model).results[1:] {
		m, _ = m.Update(key("down"))
	}
	last := m.(model).cursor
	m, _ = m.Update(key("ctrl+d"))
	m, _ = m.Update(key("y"))
	mm := m.(model)
	if mm.cursor >= len(mm.results) {
		t.Errorf("cursor %d out of range for %d results", mm.cursor, len(mm.results))
	}
	if mm.cursor != last-1 {
		t.Errorf("cursor = %d, want %d", mm.cursor, last-1)
	}
	_ = m.View()
}

func TestConfirmationPromptIsShown(t *testing.T) {
	m, _ := newTestModelAt(t)
	name := m.(model).results[0].Session.Name
	m, _ = m.Update(key("ctrl+d"))
	if !strings.Contains(m.View().Content, name) {
		t.Errorf("confirmation prompt should name the session %q", name)
	}
}

// A list row that wraps pushes every row below it down and shears the
// two-pane layout, so rows must be clipped rather than wrapped.
func TestListRowsNeverWrap(t *testing.T) {
	m := newTestModel(t)
	mm := m.(model)
	long := mm.results[0]
	long.Session.Tree = "nerv_ave_ck/very/deep/subdir"
	long.Session.Name = "an-extremely-long-session-name-that-would-wrap"
	long.Hits = make([]Hit, 1234)
	mm.results = []result{long}

	rendered := strings.Split(mm.listView(), "\n")
	if len(rendered) != 1 {
		t.Errorf("row wrapped into %d lines: %q", len(rendered), rendered)
	}
	for _, line := range rendered {
		if w := lipgloss.Width(line); w > listWidth {
			t.Errorf("row width %d exceeds listWidth %d", w, listWidth)
		}
	}
}

// With scope nerv, "8/72" invites the reading that 64 Nerv sessions failed to
// match, when 34 of them were never in scope at all.
func TestCounterDenominatorIsInScope(t *testing.T) {
	m := typeString(newTestModel(t), "payment")
	mm := m.(model)
	if mm.inScope != 4 {
		t.Errorf("inScope = %d, want 4 (nerv sessions in the fixture)", mm.inScope)
	}
	if !strings.Contains(mm.View().Content, "1/4 sessions") {
		t.Errorf("counter should read 1/4, got: %q",
			strings.Split(mm.View().Content, "\n")[0])
	}
}

func names(rs []result) []string {
	out := make([]string, len(rs))
	for i, r := range rs {
		out[i] = r.Session.Name
	}
	return out
}
