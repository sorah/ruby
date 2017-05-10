require 'thread'

pid_file = ARGV.shift
scenario = ARGV.shift
ruby_exe = ARGV.shift

# We must do this first otherwise there will be a race with the process that
# creates this process and the TERM signal below could go to that process
# instead, which will likely abort the specs process.
Process.setsid if scenario

signaled = false
mutex = Mutex.new

Signal.trap(:TERM) do
  if mutex.try_lock
    unless signaled
      signaled = true
      STDOUT.puts "signaled"
      STDOUT.flush
    end
  end
end

File.open(pid_file, "wb") { |f| f.puts Process.pid }

if scenario
  # We are sending a signal to the process group
  process = "Process.getpgrp"

  case scenario
  when "self"
    signal = %["SIGTERM"]
    process = "0"
  when "group_numeric"
    signal = %[-Signal.list["TERM"]]
  when "group_short_string"
    signal = %["-TERM"]
  when "group_full_string"
    signal = %["-SIGTERM"]
  else
    raise "unknown scenario: #{scenario.inspect}"
  end

  code = "Process.kill(#{signal}, #{process})"
  system(*ruby_exe.split(' '), "-e", code)
end

sleep 0.001 until signaled
