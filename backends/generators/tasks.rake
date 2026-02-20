# frozen_string_literal: true

require "udb/resolver"
require 'json'
require 'tempfile'

directory "#{$root}/gen/go"
directory "#{$root}/gen/c_header"
directory "#{$root}/gen/sverilog"
directory "#{$root}/gen/rust"

def with_resolved_exception_codes(cfg_arch)
  # Process ERB templates in exception codes using Ruby ERB processing
  resolved_exception_codes = []

  # Collect all exception codes from extensions and resolve ERB templates
  cfg_arch.extensions.each do |ext|
    ext.exception_codes.each do |ecode|
      # Use Ruby's ERB processing to resolve templates in exception names
      resolved_name = cfg_arch.render_erb(
        ecode.name,
        "exception code name: #{ecode.name}"
      )

      resolved_exception_codes << {
        "num"  => ecode.num,
        "name" => resolved_name,
        "var"  => ecode.var,
        "ext"  => ext.name
      }
    end
  end

  # Write resolved exception codes to a temporary JSON file
  tempfile = Tempfile.new(["resolved_exception_codes", ".json"])
  tempfile.write(JSON.pretty_generate(resolved_exception_codes))
  tempfile.flush

  begin
    yield tempfile.path # Run the generator script
  ensure
    tempfile.close
    tempfile.unlink
  end
end

namespace :gen do
  desc <<~DESC
    Generate Go code from RISC-V instruction and CSR definitions

    Options:
     * CONFIG - Configuration name (defaults to "_")
     * OUTPUT_DIR - Output directory for generated Go code (defaults to "#{$root}/gen/go")
  DESC
  task go: "#{$root}/gen/go" do
    config_name = ENV["CONFIG"] || "_"
    output_dir = ENV["OUTPUT_DIR"] || "#{$root}/gen/go/"

    # Ensure the output directory exists
    FileUtils.mkdir_p output_dir

    # Get the arch paths based on the config
    resolver = Udb::Resolver.new
    cfg_arch = resolver.cfg_arch_for(config_name)
    inst_dir = cfg_arch.path / "inst"
    csr_dir = cfg_arch.path / "csr"

    # Run the Go generator script
    # Note: The script uses --output not --output-dir
    sh "python #{$root}/backends/generators/Go/go_generator.py --inst-dir=#{inst_dir} --csr-dir=#{csr_dir} --output=#{output_dir}inst.go"
  end

  desc <<~DESC
    Generate C encoding header from RISC-V instruction and CSR definitions
    This is used by Spike, ACTs and the Sail Model

    Options:
     * CONFIG - Configuration name (defaults to "_")
     * OUTPUT_DIR - Output directory for generated C Header headers (defaults to "#{$root}/gen/c_header")
  DESC
  task c_header: "#{$root}/gen/c_header" do
    config_name = ENV["CONFIG"] || "_"
    output_dir = ENV["OUTPUT_DIR"] || "#{$root}/gen/c_header/"

    # Ensure the output directory exists
    FileUtils.mkdir_p output_dir

    # Get the arch paths based on the config
    resolver = Udb::Resolver.new
    cfg_arch = resolver.cfg_arch_for(config_name)
    inst_dir = cfg_arch.path / "inst"
    csr_dir = cfg_arch.path / "csr"
    ext_dir = cfg_arch.path / "ext"

    with_resolved_exception_codes(cfg_arch) do |resolved_codes|
      sh "python #{$root}/backends/generators/c_header/generate_encoding.py " \
         "--inst-dir=#{inst_dir} --csr-dir=#{csr_dir} --ext-dir=#{ext_dir} " \
         "--resolved-codes=#{resolved_codes} " \
         "--output=#{output_dir}encoding.out.h --include-all"
    end
  end

  desc <<~DESC
    Generate SystemVerilog package from RISC-V instruction and CSR definitions

    Options:
     * CONFIG - Configuration name (defaults to "_")
     * OUTPUT_DIR - Output directory for generated SystemVerilog code (defaults to "#{$root}/gen/sverilog")
  DESC
  task sverilog: "#{$root}/gen/sverilog" do
    config_name = ENV["CONFIG"] || "_"
    output_dir = ENV["OUTPUT_DIR"] || "#{$root}/gen/sverilog/"

    # Ensure the output directory exists
    FileUtils.mkdir_p output_dir

    # Get the arch paths based on the config
    resolver = Udb::Resolver.new
    cfg_arch = resolver.cfg_arch_for(config_name)
    inst_dir = cfg_arch.path / "inst"
    csr_dir = cfg_arch.path / "csr"
    ext_dir = cfg_arch.path / "ext"

    with_resolved_exception_codes(cfg_arch) do |resolved_codes|
      sh "python #{$root}/backends/generators/sverilog/sverilog_generator.py " \
         "--inst-dir=#{inst_dir} --csr-dir=#{csr_dir} --ext-dir=#{ext_dir} " \
         "--resolved-codes=#{resolved_codes} " \
         "--output=#{output_dir}riscv_decode_package.svh --include-all"
    end
  end

  desc <<~DESC
    Generate Rust code from RISC-V instruction and CSR definitions

    Options:
     * CONFIG - Configuration name (defaults to "_")
     * OUTPUT_DIR - Output directory for generated Rust code (defaults to "#{$root}/gen/rust")
  DESC
  task rust: "#{$root}/gen/rust" do
    config_name = ENV["CONFIG"] || "_"
    output_dir = ENV["OUTPUT_DIR"] || "#{$root}/gen/rust/"

    # Ensure the output directory exists
    FileUtils.mkdir_p output_dir

    # Get the arch paths based on the config
    resolver = Udb::Resolver.new
    cfg_arch = resolver.cfg_arch_for(config_name)
    inst_dir = cfg_arch.path / "inst"
    csr_dir = cfg_arch.path / "csr"

    # Run the Rust generator script
    sh "python #{$root}/backends/generators/rust/rust_generator.py --inst-dir=#{inst_dir} --csr-dir=#{csr_dir} --output=#{output_dir}riscv.rs --include-all"
  end
end

namespace :test do
  desc "Check the Rust generator output vs. stored golden output"
  task rust: "gen:rust" do
    files = {
      golden: {
        file: Tempfile.new("golden"),
        path: "#{File.dirname(__FILE__)}/rust/riscv.golden.rs"
      },
      output: {
        file: Tempfile.new("output"),
        path: "#{$root}/gen/rust/riscv.rs"
      }
    }

    # Filter out lines that might have non-deterministic content
    [:golden, :output].each do |which|
      file = files[which][:file]
      path = files[which][:path]

      unless File.exist?(path)
        warn "File #{path} does not exist!"
        exit 1
      end

      orig = File.read(path)
      # No filtering needed for now as we made the generator deterministic
      file.write(orig)
      file.flush
    end
    # Compare the files using Ruby to avoid platform-specific diff commands
    puts "Comparing #{files[:golden][:file].path} with #{files[:output][:file].path}"
    if FileUtils.compare_file(files[:golden][:file].path, files[:output][:file].path)
      puts "Rust generator output matches golden file"
    else
      warn "Rust generator output does not match golden file"
      # Print first few lines of difference if possible, or just fail
      # Simple diff implementation for debugging
      golden_lines = File.readlines(files[:golden][:file].path)
      output_lines = File.readlines(files[:output][:file].path)
      diffs = 0
      golden_lines.each_with_index do |line, i|
        if line != output_lines[i]
          warn "Line #{i + 1} differs:"
          warn "< #{line.chomp}"
          warn "> #{output_lines[i].chomp}"
          diffs += 1
          break if diffs >= 5
        end
      end
      warn <<~MSG
        The golden output for the Rust generator has changed. If this is expected, run

        ./do chore:update_golden_rust

        And commit backends/generators/rust/riscv.golden.rs
      MSG
      exit 1
    end
  end
end
