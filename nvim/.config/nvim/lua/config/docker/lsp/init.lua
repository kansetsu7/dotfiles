local registry = require 'mason-registry'
for _, package_name in ipairs { 'lua-language-server', 'stylua' } do
  local ok, package = pcall(function()
    return registry.get_package(package_name)
  end)
  if ok and (not package:is_installed()) then
    -- Override the installation options
    package:install {
      target = 'linux_arm64_gnu', -- Specify the target platform manually if supported
    }
  end
end
