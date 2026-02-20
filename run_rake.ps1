# Start with ostruct in RUBYLIB
$ostruct_lib = "C:/Ruby40-x64/lib/ruby/gems/4.0.0/gems/ostruct-0.6.3/lib"
$lib_paths = @($ostruct_lib)

# Add local gem libs
$local_gems = @("udb", "udb_helpers", "idlc", "udb-gen", "idl_highlighter")
foreach ($gem in $local_gems) {
    if (Test-Path "tools/ruby-gems/$gem/lib") {
        $lib_paths += (Resolve-Path "tools/ruby-gems/$gem/lib").Path
    }
}

# Scan system gems and add them
$system_gems_path = "C:/Ruby40-x64/lib/ruby/gems/4.0.0/gems"
if (Test-Path $system_gems_path) {
    Get-ChildItem -Path $system_gems_path -Directory | ForEach-Object {
        $lib_path = Join-Path $_.FullName "lib"
        if (Test-Path $lib_path) {
            $lib_paths += $lib_path
        }
    }
}

$env:RUBYLIB = ($lib_paths -join ";")
$env:BUNDLE_GEMFILE = (Resolve-Path "Gemfile").Path # explicitly set but we will try to avoid exec
$env:RUBYOPT = "" # Clear any rubyopt

write-host "RUBYLIB set (length: $($env:RUBYLIB.Length))"

rake $args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
