-- ============================
--  share clipboard with macOS
-- ============================
-- needs to run below commands in macOS terminal
-- ```
-- socat TCP-LISTEN:8377,reuseaddr,fork SYSTEM:"pbcopy" &
-- socat TCP-LISTEN:8378,reuseaddr,fork EXEC:"pbpaste" &
-- ```
vim.g.clipboard = {
  name = "socat",
  copy = {
    ["+"] = "nc -N host.docker.internal 8377",
    ["*"] = "nc -N host.docker.internal 8377",
  },
  paste = {
    ["+"] = "nc host.docker.internal 8378",
    ["*"] = "nc host.docker.internal 8378",
  },
}
