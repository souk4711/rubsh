# Rubsh

Rubsh (a.k.a. ruby-sh) - Inspired by [python-sh], allows you to call any program as if it were a function:

```ruby
require 'rubsh'

sh = Rubsh.new
print(sh.cmd('ifconfig').call_with('wlan0').stdout_data)
```

Output:

```text
wlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.1.13  netmask 255.255.255.0  broadcast 192.168.1.255
        inet6 fe80::7fab:2715:9e90:2061  prefixlen 64  scopeid 0x20<link>
        inet6 240e:3b7:3278:9fa0:e48:24:7958:9128  prefixlen 64  scopeid 0x0<global>
        ether 14:85:7f:08:5b:2e  txqueuelen 1000  (Ethernet)
        RX packets 6015867  bytes 7575465908 (7.0 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2953567  bytes 391257693 (373.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

Note that these aren't Ruby functions, these are running the binary commands on your system by dynamically resolving your $PATH, much like Bash does, and then wrapping the binary in a function. In this way, all the programs on your system are easily available to you from within Ruby.

When using this library you can:

* Call any program as if it were a function.
* Get an exception when exit code is not 0.
* Force terminate the process if it does not finish within the timeout.
* Always split the shell command into tokens, reduce command injection risk.
* etc.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-sh', require: 'rubsh'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ruby-sh


## Usage

### Basic Syntax

```ruby
# Create a shell
sh = Rubsh.new

# Create a command, use `command`/`cmd`
cmd = sh.cmd("ls")

# Invoke a command, use `call`/`call_with`
result = cmd.call_with("-la")

# Print result
print result.stdout_data
```

### Passing Arguments

```ruby
sh.cmd("ls").call_with("-l", "/tmp", color: "always", human_readable: true)
  # => ["/usr/bin/ls", "-l", "/tmp", "--color=always", "--human-readable"]

sh.cmd("curl").call_with("https://www.ruby-lang.org/", o: "page.html", silent: true)
  # => ["/usr/bin/curl", "https://www.ruby-lang.org/", "-opage.html", "--silent"]

sh.cmd("git").call(:status, { v: true })
  # => ["/usr/bin/git", "status", "-v"]

sh.cmd("git").call(:status, { v: true }, "--", ".")
  # => ["/usr/bin/git", "status", "-v", "--", "."]

sh.cmd("git").call(:status, { v: proc{ true }, short: true }, "--", ".")
  # => ["/usr/bin/git", "status", "-v", "--short", "--", "."]

sh.cmd("git").call(:status, { v: true }, v: false)
  # => ["/usr/bin/git", "status"]
```

### Exit Codes

```ruby
# Successful
r = sh.cmd("ls").call_with("/")
r.exit_code # => 0

# a `CommandReturnFailureError` raised when run failure
begin
  sh.cmd("ls").call_with("/some/non-existant/folder")
rescue Rubsh::Exceptions::CommandReturnFailureError => e
  e.exit_code # => 2
end

# Treats as success use `:_ok_code`
r = sh.cmd("ls").call_with("/some/non-existant/folder", _ok_code: [0, 1, 2])
r = sh.cmd("ls").call_with("/some/non-existant/folder", _ok_code: 0..2)
r.exit_code # => 2
```

### Redirection

```ruby
# Filename
sh.cmd("ls").call_with(_out: "/tmp/dir_content")
sh.cmd("ls").call_with(_out: ["/tmp/dir_content", "w"])
sh.cmd("ls").call_with(_out: ["/tmp/dir_content", "w", 0600])
sh.cmd("ls").call_with(_out: ["/tmp/dir_content", File::WRONLY|File::EXCL|File::CREAT, 0600])

# File object
File.open("/tmp/dir_content", "w") { |f| sh.cmd("ls").call_with(_out: f) }

# `stdout_data` & `stderr_data`
r = sh.cmd("sh").call_with("-c", "echo out; echo err >&2")
r.stdout_data # => "out\n"
r.stderr_data # => "err\n"

# Redirects stderr and stderr to the same place use `_err_to_out`
r = sh.cmd("sh").call_with("-c", "echo out; echo err >&2", _err_to_out: true)
r.stdout_data # => "out\nerr\n"
r.stderr_data # => nil

# Read input from data
sh.cmd("cat").call_with(_in_data: "hello").stdout_data # => "hello"

# Read input from file
sh.cmd("cat").call_with(_in: "/some/existant/file")
```

### Incremental Iteration

```ruby
# By default, output is line-buffered, so the body of the loop will only run
# when your process produces a newline. You can change this by changing the
# buffer size of the command’s output with `_out_bufsize`/`_err_bufsize`.
tail = sh.cmd("tail")
tail.call_with("-f", "/var/log/some_log_file.log", _capture: ->(stdout, _stderr) {
  print stdout
})
```

### Background Processes

```ruby
# Blocks
sh.cmd("sleep").call_with(3)
p "...3 seconds later"

# Doesn't block
r = sh.cmd("sleep").call_with(3, _bg: true)
p "prints immediately!"
r.wait()
p "...and 3 seconds later"

# Timeout
r = sh.cmd("sleep").call_with(30, _bg: true)
p "prints immediately!"
r.wait(timeout: 3)
p "...and 3 seconds later"
```

### Baking

```ruby
ll = sh.cmd("ls").bake("-l")
ll.call_with("/tmp") # => ["/usr/bin/ls", "-l", "/tmp"]

# Equivalent
sh.cmd("ls").call_with("-l", "/tmp")

# Calling whoami on a server. this is a lot to type out, especially if you wanted
# to call many commands (not just whoami) back to back on the same server resolves
# to "/usr/bin/ssh myserver.com -p 1393 whoami"
sh.cmd('ssh').call_with("myserver.com", "-p 1393", "whoami")

# Wouldn't it be nice to bake the common parameters into the ssh command?
myserver = sh.cmd('ssh').bake("myserver.com", p: 1393)
myserver.call_with('whoami')
myserver.call_with('pwd')
```

### Subcommands

```ruby
# Use `bake`
gst = sh.cmd("git").bake("status")

gst.call_with() # => ["/usr/bin/git", "status"]
gst.call_with("-s") # => ["/usr/bin/git", "status", "-s"]
```

### Piping

```ruby
# Run a series of commands connected by `_pipeline`
r = sh.pipeline(_in_data: "hello world") do |pipeline|
  sh.cmd("cat").call_with(_pipeline: pipeline)
  sh.cmd("wc").call_with("-c", _pipeline: pipeline)
end
r.stdout_data # => "11\n"
```


## Reference

### Special Kwargs

* `_in_data`:
  * use: Specifies an argument for the process to use as its standard input data.
  * default value: `nil`
* `_in`:
  * use: Specifies an argument for the process to use as its standard input.
  * default value: `nil`
* `_out`:
  * use: Where to redirect STDOUT to.
  * default value: `nil`
* `_err`:
  * use: Where to redirect STDERR to.
  * default value: `nil`
* `_err_to_out`:
  * use: If true, duplicate the file descriptor bound to the process’s STDOUT also to STDERR.
  * default value: `false`
* `_capture`:
  * use: Iterates over STDOUT/STDERR.
  * default value: `nil`
* `_bg`:
  * use: Runs a command in the background. The command will return immediately, and you will have to run RunningCommand#wait on it to ensure it terminates.
  * default value: `false`
* `_timeout`:
  * use: How much time, in seconds, we should give the process to complete. If the process does not finish within the timeout, it will be terminated.
  * default value: `nil`
* `_env`:
  * use: A dictionary defining the only environment variables that will be made accessible to the process. If not specified, the calling process’s environment variables are used.
  * default value: `nil`
* `_cwd`:
  * use: Current working directory of the process.
  * default value: `nil`
* `_ok_code`:
  * use: Some misbehaved programs use exit codes other than 0 to indicate success. Set to treats as success.
  * default value: `[0]`
* `_no_out`:
  * use: Disables STDOUT being internally stored. This is useful for commands that produce huge amounts of output that you don’t need, that would otherwise be hogging memory if stored internally by Rubsh.
  * default value: `false`
* `_no_err`:
  * use: Disables STDERR being internally stored. This is useful for commands that produce huge amounts of output that you don’t need, that would otherwise be hogging memory if stored internally by Rubsh.
  * default value: `false`
* `_out_bufsize`:
  * use: The STDOUT buffer size. nil for unbuffered, 0 for line buffered, anything else for a buffer of that amount.
  * default value: `0`
* `_err_bufsize`:
  * use: The STDERR buffer size. nil for unbuffered, 0 for line buffered, anything else for a buffer of that amount.
  * default value: `0`
* `_long_sep`:
  * use: This is the character(s) that separate a program’s long argument’s key from the value.
  * default value: `"="`
* `_long_prefix`:
  * use: This is the character(s) that prefix a long argument for the program being run. Some programs use single dashes, for example, and do not understand double dashes.
  * default value: `"--"`
* `_pipeline`:
  * use: Specifies the :pipeline.
  * default value: `nil`


## FAQ

### Why doesn’t `*` work as a command argument?

Glob expansion is a feature of a shell, like Bash, and is performed by the shell before passing the results to the program to be exec'd. Because Rubsh is not a shell, but rather tool to execute programs directly, we do not handle glob expansion like a shell would.

### How do I execute a bash builtin?

```ruby
sh = Rubsh.new
rawsh = sh.cmd('bash').bake('-c')
print(rawsh.call_with('echo Hello').stdout_data) # => "Hello\n"
```

### How do I call a program that isn’t in $PATH?

Use absolute binpath

```ruby
sh = Rubsh.new
sh.cmd('/path/to/command').call()
```

Or use `Rubsh::Shell::Env#path`

```ruby
sh = Rubsh.new
sh.env.path << "/dir/to/command/"
sh.cmd('command').call()
```

### How do I run a command and connect it to stdout and stdin?

Use `_capture` special kwargs.

### How do I order keyword arguments?

Typically this question gets asked when a user is trying to execute something like the following commandline:

```sh
my-command --arg1=val1 arg2 --arg3=val3
```

Use:

```ruby
sh = Rubsh.new
sh.cmd('my-command').call_with({ arg1: "val1" }, "args2", { arg3: "val3" })
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/souk4711/rubsh. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/souk4711/rubsh/blob/main/CODE_OF_CONDUCT.md).


## Acknowledgements

* Special thanks to [python-sh].


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Code of Conduct

Everyone interacting in the Rubsh project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/souk4711/rubsh/blob/main/CODE_OF_CONDUCT.md).


[python-sh]:https://github.com/amoffat/sh
