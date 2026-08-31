package main

import (
	"strings"

	"charm.land/lipgloss/v2"
)

// highlight wraps every case-insensitive occurrence of query in matchStyle.
// It walks the lowercased copy to find offsets but slices the original, so the
// rendered text keeps its original casing.
func highlight(text, query string) string {
	if query == "" {
		return text
	}
	lowerText, lowerQuery := strings.ToLower(text), strings.ToLower(query)
	var b strings.Builder
	for {
		i := strings.Index(lowerText, lowerQuery)
		if i < 0 {
			b.WriteString(text)
			return b.String()
		}
		b.WriteString(text[:i])
		b.WriteString(matchStyle.Render(text[i : i+len(query)]))
		text, lowerText = text[i+len(query):], lowerText[i+len(query):]
	}
}

// snippet returns at most limit bytes of text centred on the first match.
// Tool results can run to megabytes; rendering one whole would stall the UI
// and bury the match.
func snippet(text, query string, limit int) string {
	text = strings.TrimSpace(text)
	if len(text) <= limit {
		return text
	}
	start := 0
	if query != "" {
		if i := strings.Index(strings.ToLower(text), strings.ToLower(query)); i > 0 {
			start = max(0, i-limit/3)
		}
	}
	end := min(len(text), start+limit)
	out := text[start:end]
	if start > 0 {
		out = "…" + out
	}
	if end < len(text) {
		out += "…"
	}
	return out
}

// wrap hard-wraps to w columns. lipgloss is ANSI-aware, so this is safe to
// apply to text that highlight has already styled.
func wrap(s string, w int) string {
	return lipgloss.NewStyle().Width(w).Render(s)
}

// trunc shortens s to n display cells, rune-safe.
func trunc(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	if n <= 1 {
		return string(r[:n])
	}
	return string(r[:n-1]) + "…"
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
