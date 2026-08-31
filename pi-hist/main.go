// pi-hist — interactive search across pi session transcripts, spanning every
// Nerv worktree.
//
// pi keys session storage off `pwd`, so a session started in /proj/nerv_hk is
// only resumable there and `/resume` in a sibling worktree will never list it.
// The four Nerv worktrees are subsidiaries of one codebase sharing most
// features, so "which worktree was I in when I solved this?" is usually the
// wrong question to have to answer.
//
// An earlier attempt consolidated the storage directories with symlinks. That
// was wrong: a transcript records absolute paths in every tool call, so
// resuming a nerv_ck session with cwd nerv_hk fills the context with paths
// that contradict the working directory, and the model edits the wrong
// worktree without any error being raised.
//
// Searching carries no such hazard: it is read-only and the transcript never
// becomes the working context.
//
// Enter closes the loop safely. Rather than resuming in whatever directory you
// happen to be standing in, it chdirs to the cwd recorded in the transcript
// and execs pi there, so the working directory and the paths inside the
// session always agree — precisely the invariant the symlink approach broke.
// Because a child process cannot move its parent shell, the chdir applies to
// pi only; your shell is where you left it once pi exits.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"charm.land/bubbles/v2/textinput"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

const (
	// Wide enough for marker(2) + date(5) + tree(12) + name(16) + count(5)
	// plus separators. Rows are also hard-clipped to this: a row that wraps
	// pushes every subsequent row down and shears the two-pane layout.
	listWidth   = 46
	chromeLines = 6 // title + search + pane header + footer + padding
)

var (
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("205"))
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("242"))
	selStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("213"))
	treeStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("079"))
	matchStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("0")).Background(lipgloss.Color("220"))
	roleStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("111"))
	headerStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	warnStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("0")).Background(lipgloss.Color("203"))
	errStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("203"))
	okStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("114"))
)

type result struct {
	Session   Session
	Hits      []Hit
	NameMatch bool
}

type model struct {
	all      []Session
	results  []result
	cursor   int
	offset   int // first visible list row
	input    textinput.Model
	preview  viewport.Model
	nervOnly bool
	inScope  int // sessions passing the scope filter, before the query
	width    int
	height   int
	chosen   *Session
	roots    []string

	// pending holds the session awaiting delete confirmation. Deleting a
	// transcript is irreversible and it is the only record of that work, so
	// removal is always gated behind an explicit keystroke.
	pending *Session
	status  string // transient result line, cleared on the next keypress
}

func initialModel(all []Session, query string, nervOnly bool) model {
	ti := textinput.New()
	ti.Placeholder = "type to search transcripts…"
	ti.SetValue(query)
	ti.Focus()

	m := model{
		all:      all,
		input:    ti,
		preview:  viewport.New(),
		nervOnly: nervOnly,
		roots:    nervRoots(),
	}
	m.recompute()
	return m
}

// recompute rebuilds the visible result set. With an empty query every
// in-scope session is listed (browse mode); otherwise a session survives if
// its name matches or any message does.
//
// Name matches are listed first. A session name is a label you chose for the
// work, so it is a stronger signal than an incidental mention buried in a
// transcript. Building the two groups separately keeps the sort stable, so
// within each group sessions stay in recency order.
func (m *model) recompute() {
	query := m.input.Value()
	m.results = m.results[:0]
	m.inScope = 0
	var contentOnly []result
	for _, s := range m.all {
		if m.nervOnly && !isNerv(s.CWD, m.roots) {
			continue
		}
		m.inScope++
		if query == "" {
			m.results = append(m.results, result{Session: s})
			continue
		}
		hits := s.Search(query)
		nameMatch := s.NameMatches(query)
		if !nameMatch && len(hits) == 0 {
			continue
		}
		r := result{Session: s, Hits: hits, NameMatch: nameMatch}
		if nameMatch {
			m.results = append(m.results, r)
		} else {
			contentOnly = append(contentOnly, r)
		}
	}
	m.results = append(m.results, contentOnly...)
	if m.cursor >= len(m.results) {
		m.cursor = max(0, len(m.results)-1)
	}
	m.offset = 0
	m.syncPreview()
}

// ensureVisible scrolls the list so the cursor stays on screen.
func (m *model) ensureVisible() {
	rows := m.visibleRows()
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+rows {
		m.offset = m.cursor - rows + 1
	}
	if m.offset > 0 && m.offset+rows > len(m.results) {
		m.offset = max(0, len(m.results)-rows)
	}
}

// deleteSession removes a transcript from disk and drops it from the loaded
// set. The cursor is held in place rather than reset, so a run of unwanted
// sessions can be cleared without re-navigating after each one.
func (m *model) deleteSession(s Session) {
	if err := os.Remove(s.Path); err != nil {
		m.status = errStyle.Render(fmt.Sprintf("could not delete %s: %v", s.Name, err))
		return
	}
	for i, x := range m.all {
		if x.Path == s.Path {
			m.all = append(m.all[:i], m.all[i+1:]...)
			break
		}
	}
	cursor := m.cursor
	m.recompute()
	m.cursor = clamp(cursor, 0, max(0, len(m.results)-1))
	m.ensureVisible()
	m.syncPreview()
	m.status = okStyle.Render(fmt.Sprintf("deleted %s", s.Name))
}

func (m *model) visibleRows() int {
	return max(1, m.height-chromeLines)
}

// syncPreview re-renders the right pane for the current selection.
func (m *model) syncPreview() {
	if len(m.results) == 0 {
		m.preview.SetContent(dimStyle.Render("  no matching sessions"))
		return
	}
	r := m.results[m.cursor]
	w := max(20, m.width-listWidth-4)

	var b strings.Builder
	b.WriteString(headerStyle.Render(r.Session.Time.Format("2006-01-02 15:04")) + "\n")
	b.WriteString(treeStyle.Render(r.Session.Tree) + "  " + selStyle.Render(r.Session.Name) + "\n")
	b.WriteString(dimStyle.Render(r.Session.Path) + "\n\n")

	query := m.input.Value()
	switch {
	case query == "":
		b.WriteString(dimStyle.Render(fmt.Sprintf("%d messages — type to search", len(r.Session.Messages))))
		if first, ok := firstUser(r.Session); ok {
			b.WriteString("\n\n" + roleStyle.Render("first message") + "\n")
			b.WriteString(wrap(snippet(first, "", 400), w))
		}
	case len(r.Hits) == 0:
		// Matched on the name alone; show the opening message so there is
		// still something to judge the session by.
		b.WriteString(dimStyle.Render("matched on session name"))
		if first, ok := firstUser(r.Session); ok {
			b.WriteString("\n\n" + roleStyle.Render("first message") + "\n")
			b.WriteString(wrap(snippet(first, "", 400), w))
		}
	default:
		for i, h := range r.Hits {
			if i > 0 {
				b.WriteString("\n")
			}
			b.WriteString(roleStyle.Render(h.Msg.Role) + "\n")
			text := snippet(h.Msg.Text, query, 400)
			b.WriteString(wrap(highlight(text, query), w) + "\n")
		}
	}
	m.preview.SetContent(b.String())
	m.preview.GotoTop()
}

func firstUser(s Session) (string, bool) {
	for _, m := range s.Messages {
		if m.Role == "user" {
			return m.Text, true
		}
	}
	return "", false
}

func (m model) Init() tea.Cmd { return textinput.Blink }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch t := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = t.Width, t.Height
		m.preview.SetWidth(max(20, m.width-listWidth-4))
		m.preview.SetHeight(m.visibleRows())
		m.syncPreview()
		return m, nil

	case tea.KeyPressMsg:
		// While a delete is pending, every key is consumed by the prompt so
		// nothing leaks into the search input and only "y" can destroy a file.
		if m.pending != nil {
			s := *m.pending
			m.pending = nil
			if t.String() == "y" {
				m.deleteSession(s)
			} else {
				m.status = dimStyle.Render("delete cancelled")
			}
			return m, nil
		}
		m.status = ""

		switch t.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit
		case "enter":
			if len(m.results) > 0 {
				s := m.results[m.cursor].Session
				m.chosen = &s
			}
			return m, tea.Quit
		// ctrl+j/ctrl+k are handled here, ahead of the search input, so they
		// shadow textinput's own bindings: ctrl+k would otherwise kill to end
		// of line. ctrl+u still clears the query, which is what that binding
		// was realistically used for in a single-line field.
		case "up", "ctrl+k":
			m.move(-1)
			return m, nil
		case "down", "ctrl+j":
			m.move(1)
			return m, nil
		case "pgup":
			m.preview.ScrollUp(m.visibleRows() / 2)
			return m, nil
		case "pgdown":
			m.preview.ScrollDown(m.visibleRows() / 2)
			return m, nil
		case "ctrl+d":
			if len(m.results) > 0 {
				s := m.results[m.cursor].Session
				m.pending = &s
			}
			return m, nil
		case "tab":
			m.nervOnly = !m.nervOnly
			m.recompute()
			return m, nil
		}
	}

	before := m.input.Value()
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	if m.input.Value() != before {
		m.cursor = 0
		m.recompute()
	}
	return m, cmd
}

func (m *model) move(d int) {
	if len(m.results) == 0 {
		return
	}
	m.cursor = clamp(m.cursor+d, 0, len(m.results)-1)
	m.ensureVisible()
	m.syncPreview()
}

func (m model) View() tea.View {
	if m.width == 0 {
		return tea.NewView("loading…")
	}

	scope := "all"
	if m.nervOnly {
		scope = "nerv"
	}
	// Denominator is the in-scope count, not the global total: with scope
	// nerv, "8/72" invites the reading that 64 Nerv sessions failed to match.
	title := titleStyle.Render("pi-hist") + dimStyle.Render(fmt.Sprintf(
		"  %d/%d sessions · scope %s", len(m.results), m.inScope, scope))

	body := lipgloss.JoinHorizontal(lipgloss.Top, m.listView(), "  ", m.preview.View())

	var footer string
	switch {
	case m.pending != nil:
		footer = warnStyle.Render(fmt.Sprintf(" delete %q (%s)? ", m.pending.Name, m.pending.Tree)) +
			dimStyle.Render("  y = delete permanently · any other key = cancel")
	case m.status != "":
		footer = m.status
	default:
		footer = dimStyle.Render("↑↓ select · tab scope · ^d delete · ⏎ resume in worktree · esc quit")
	}

	v := tea.NewView(strings.Join([]string{title, m.input.View(), body, footer}, "\n"))
	v.AltScreen = true
	return v
}

func (m model) listView() string {
	rows := m.visibleRows()
	query := m.input.Value()
	var b strings.Builder
	if len(m.results) == 0 {
		b.WriteString(dimStyle.Render("no matches"))
	}
	for i := m.offset; i < len(m.results) && i < m.offset+rows; i++ {
		r := m.results[i]
		marker := "  "
		if i == m.cursor {
			marker = selStyle.Render("▸ ")
		}
		count := ""
		if n := len(r.Hits); n > 0 {
			count = dimStyle.Render(fmt.Sprintf(" (%d)", n))
		}
		// Highlighting the name is the cue for why a name-only match is in
		// the list at all — it has no hit count to show.
		name := highlight(trunc(r.Session.Name, 16), query)
		line := marker +
			dimStyle.Render(r.Session.Time.Format("01-02")) + " " +
			treeStyle.Render(trunc(r.Session.Tree, 12)) + " " +
			name + count
		// clip per row so no content can wrap into the next line
		b.WriteString(lipgloss.NewStyle().MaxWidth(listWidth).Render(line) + "\n")
	}
	return lipgloss.NewStyle().Width(listWidth).MaxWidth(listWidth).Render(
		strings.TrimRight(b.String(), "\n"))
}

func main() {
	var (
		query = flag.String("q", "", "initial search query")
		all   = flag.Bool("a", false, "search every session, not just Nerv worktrees")
	)
	flag.Usage = func() {
		fmt.Fprint(os.Stderr, `pi-hist — interactive search across pi session history

  pi-hist [-q query] [-a]

  -q   start with a search query
  -a   search every session, not just Nerv worktrees

Enter chdirs to the worktree the session was recorded in and resumes it
there, so the working directory always matches the paths in the transcript.
`)
	}
	flag.Parse()

	root := sessionRoot()
	sessions, err := LoadSessions(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "pi-hist: %v\n", err)
		os.Exit(1)
	}
	if len(sessions) == 0 {
		fmt.Fprintf(os.Stderr, "pi-hist: no sessions found under %s\n", root)
		os.Exit(1)
	}

	m := initialModel(sessions, *query, !*all)
	final, err := tea.NewProgram(m).Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "pi-hist: %v\n", err)
		os.Exit(1)
	}
	// Runs after the alt screen is torn down, so pi inherits a clean terminal.
	if fm, ok := final.(model); ok && fm.chosen != nil {
		resume(*fm.chosen)
	}
}

// resume chdirs into the session's recorded working directory and replaces
// this process with pi.
//
// Replacing rather than spawning matters: pi then owns the terminal outright,
// inherits the exit status, and there is no idle parent left holding the tty.
// The chdir binds to this process, so it reaches pi but cannot move the
// calling shell — a child can never do that. Exiting pi therefore returns you
// to the directory you started in.
func resume(s Session) {
	fi, err := os.Stat(s.CWD)
	if err != nil || !fi.IsDir() {
		// A worktree can be removed long after its transcripts were written.
		fmt.Fprintf(os.Stderr,
			"pi-hist: the session's working directory no longer exists: %s\n"+
				"  transcript: %s\n", s.CWD, s.Path)
		os.Exit(1)
	}
	piPath, err := exec.LookPath("pi")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pi-hist: cannot find pi on PATH: %v\n", err)
		os.Exit(1)
	}
	if err := os.Chdir(s.CWD); err != nil {
		fmt.Fprintf(os.Stderr, "pi-hist: cannot enter %s: %v\n", s.CWD, err)
		os.Exit(1)
	}
	args := []string{"pi", "--session", s.Path}
	if err := syscall.Exec(piPath, args, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "pi-hist: cannot exec pi: %v\n", err)
		os.Exit(1)
	}
}
