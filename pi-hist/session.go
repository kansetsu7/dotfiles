// Session loading and searching for pi-hist.
//
// Sessions are located by the `cwd` recorded in each transcript's header line,
// NOT by the directory name pi derives from it. pi keys session storage off
// `pwd`, so work started in /proj/nerv_hk lands in --proj-nerv_hk-- and is
// invisible to `/resume` from any sibling worktree. Reading the recorded cwd
// instead means this keeps working across the consolidated archive directory,
// per-worktree directories that stock pi recreates, sessions started at
// $PROJECT_PATH, and worktrees added later.

package main

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Entry is the subset of a transcript line this tool cares about. A session
// file is JSONL: one of these per line, discriminated by Type.
type Entry struct {
	Type      string          `json:"type"`
	CWD       string          `json:"cwd"`
	Timestamp string          `json:"timestamp"`
	Name      string          `json:"name"`
	Message   json.RawMessage `json:"message"`
}

type rawMessage struct {
	Role    string `json:"role"`
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
}

// Message is one text-bearing conversation turn. Tool output is discarded at
// parse time: it is the bulk of a transcript (file dumps, diffs, grep output)
// and searching it buries the conversation you are actually looking for.
type Message struct {
	Role string
	Text string
}

type Session struct {
	Path     string
	CWD      string
	Tree     string // path relative to $PROJECT_PATH, e.g. nerv_hk/lilith
	Name     string
	Time     time.Time
	Messages []Message
}

// Hit is a message within a session that matched the active query.
type Hit struct {
	Index int
	Msg   Message
}

const unnamed = "(unnamed)"

func sessionRoot() string {
	if v := os.Getenv("PI_SESSION_ROOT"); v != "" {
		return v
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".pi/agent/sessions"
	}
	return filepath.Join(home, ".pi", "agent", "sessions")
}

func projectPath() string {
	if v := os.Getenv("PROJECT_PATH"); v != "" {
		return v
	}
	return "/proj"
}

// nervRoots returns the absolute worktree paths. docker sets NERV_PREFIX to
// "nerv_" (/proj/nerv_hk); mac leaves it empty (~/proj/hk), so the prefix must
// come from the environment rather than being hardcoded — a literal "nerv"
// match finds nothing on mac.
func nervRoots() []string {
	prefix, ok := os.LookupEnv("NERV_PREFIX")
	if !ok {
		prefix = "nerv_"
	}
	trees := strings.Fields(os.Getenv("NERV_WORKTREES"))
	if len(trees) == 0 {
		trees = []string{"hk", "ck", "sg", "ave_ck"}
	}
	roots := make([]string, 0, len(trees))
	for _, t := range trees {
		roots = append(roots, filepath.Join(projectPath(), prefix+t))
	}
	return roots
}

// isNerv reports whether cwd is a Nerv worktree or a directory inside one.
// The boundary check stops /proj/nerv_hk_scratch from matching while still
// admitting /proj/nerv_hk/lilith.
func isNerv(cwd string, roots []string) bool {
	for _, r := range roots {
		if cwd == r || strings.HasPrefix(cwd, r+string(os.PathSeparator)) {
			return true
		}
	}
	return false
}

func relTree(cwd string) string {
	base := projectPath() + string(os.PathSeparator)
	if strings.HasPrefix(cwd, base) {
		return strings.TrimPrefix(cwd, base)
	}
	return cwd
}

// LoadSessions reads every transcript under the session root. Malformed lines
// and unreadable files are skipped rather than fatal: a truncated transcript
// from a killed pi process should not take down the whole search.
func LoadSessions(root string) ([]Session, error) {
	matches, err := filepath.Glob(filepath.Join(root, "*", "*.jsonl"))
	if err != nil {
		return nil, err
	}
	sessions := make([]Session, 0, len(matches))
	for _, path := range matches {
		s, ok := loadOne(path)
		if ok {
			sessions = append(sessions, s)
		}
	}
	sort.Slice(sessions, func(i, j int) bool {
		return sessions[i].Time.After(sessions[j].Time)
	})
	return sessions, nil
}

func loadOne(path string) (Session, bool) {
	f, err := os.Open(path)
	if err != nil {
		return Session{}, false
	}
	defer f.Close()

	s := Session{Path: path, Name: unnamed}
	sc := bufio.NewScanner(f)
	// Transcripts embed whole file reads and diffs, so single lines can be
	// megabytes; the default 64K scanner limit would truncate them.
	sc.Buffer(make([]byte, 0, 1024*1024), 32*1024*1024)

	for sc.Scan() {
		var e Entry
		if json.Unmarshal(sc.Bytes(), &e) != nil {
			continue
		}
		switch e.Type {
		case "session":
			s.CWD = e.CWD
			if t, err := time.Parse(time.RFC3339, e.Timestamp); err == nil {
				s.Time = t
			}
		case "session_info":
			// A session may be renamed more than once; last one wins.
			if e.Name != "" {
				s.Name = e.Name
			}
		case "message":
			var m rawMessage
			if json.Unmarshal(e.Message, &m) != nil {
				continue
			}
			if m.Role != "user" && m.Role != "assistant" {
				continue
			}
			for _, c := range m.Content {
				if c.Type != "text" || strings.TrimSpace(c.Text) == "" {
					continue
				}
				s.Messages = append(s.Messages, Message{Role: m.Role, Text: c.Text})
			}
		}
	}
	if s.CWD == "" {
		return Session{}, false
	}
	s.Tree = relTree(s.CWD)
	return s, true
}

// Search returns the messages in s matching query. An empty query matches the
// session itself but yields no hits, so browsing without a query still works.
func (s Session) Search(query string) []Hit {
	if query == "" {
		return nil
	}
	needle := strings.ToLower(query)
	var hits []Hit
	for i, m := range s.Messages {
		if strings.Contains(strings.ToLower(m.Text), needle) {
			hits = append(hits, Hit{Index: i, Msg: m})
		}
	}
	return hits
}
