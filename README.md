# Rubsh

Inspired by [python-sh], rubsh allows you to call any program as if it were a function:

```ruby
Rubsh.cmd('ifconfig').('wlan0')
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

rubsh relies on various Unix system calls and only works on Unix-like operating systems - Linux, macOS, BSDs etc. Specifically, Windows is not supported.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rubsh'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rubsh


## Usage

### Passing Arguments

```ruby
# resolves to "/usr/bin/ls -l /tmp --color=always"
Rubsh.cmd("ls").("-l", "/tmp", color: "always")

# resolves to "/usr/bin/curl https://www.ruby-lang.org/ -opage.html --silent"
Rubsh.cmd("curl").("https://www.ruby-lang.org/", o: "page.html", silent: true)

# or if you prefer not to use keyword arguments, this does the same thing:
Rubsh.cmd("curl").("https://www.ruby-lang.org/", "-o", "page.html", "--silent")

```

### Exit Codes

```ruby
r = Rubsh.cmd("ls").("/")
r.exit_code # => 0

# a `CommandReturnFailureError` raised when run failure
begin
  Rubsh.cmd("ls").("/some/non-existant/folder")
rescue Rubsh::Exceptions::CommandReturnFailureError => e
  e.exit_code # => 2
end

# treats as success use `:_ok_code`
r = Rubsh.cmd("ls").("/some/non-existant/folder", _ok_code: [0, 1, 2])
r = Rubsh.cmd("ls").("/some/non-existant/folder", _ok_code: 0..2)
r.exit_code # => 2
```

### Redirection

```ruby
# filename
Rubsh.cmd("ls").(_out: "/tmp/dir_content")
Rubsh.cmd("ls").(_out: ["/tmp/dir_content", "w"])
Rubsh.cmd("ls").(_out: ["/tmp/dir_content", "w", 0600])
Rubsh.cmd("ls").(_out: ["/tmp/dir_content", File::WRONLY|File::EXCL|File::CREAT, 0600])

# file object
File.open("/tmp/dir_content", "w") { |f| Rubsh.cmd("ls").(_out: f) }

# `stdout_data` & `stderr_data`
r = Rubsh.cmd("sh").("-c", "echo out; echo err >&2")
r.stdout_data # => "out\n"
r.stderr_data # => "err\n"

# redirects stderr and stderr to the same place use `_err_to_out`
r = Rubsh.cmd("sh").("-c", "echo out; echo err >&2", _err_to_out: true)
r.stdout_data # => "out\nerr\n"
r.stderr_data # => nil
```

### Baking

```ruby
# resolves to "/usr/bin/ls -l /tmp"
ll = Rubsh.cmd("ls").bake("-l")
ll.("/tmp")

# equivalent
Rubsh.cmd("ls").("-l", "/tmp")

# calling whoami on a server. this is a lot to type out, especially if you wanted
# to call many commands (not just whoami) back to back on the same server
# resolves to "/usr/bin/ssh myserver.com -p 1393 whoami"
Rubsh.cmd('ssh').("myserver.com", "-p 1393", "whoami")

# wouldn't it be nice to bake the common parameters into the ssh command?
myserver = Rubsh.cmd('ssh').bake("myserver.com", p: 1393)
myserver.('whoami')
myserver.('pwd')
```

### Piping

```ruby
r = Rubsh.pipeline do |pipeline|
  Rubsh.cmd("echo").("hello world", _pipeline: pipeline)
  Rubsh.cmd("wc").("-c", _pipeline: pipeline)
end.()
r.stdout_data # -> "12\n"
```

### Subcommands

```ruby
# `subcommand` is just a alias method of `bake`
gst = Rubsh.cmd("git").subcommand("status")

# resolves to "/usr/bin/git status"
gst.()

# resolves to "/usr/bin/git status -s"
gst.("-s")
```

### Background Processes

```ruby
# NotImplementedError
```

### Special Kwargs - work with `Rubsh::Command#bake` & `Rubsh::Command#call`

```ruby
# _out:
#   use: Where to redirect STDOUT to.
#   default value: nil

# _err:
#   use: Where to redirect STDERR to.
#   default value: nil

# _err_to_out:
#   use: If true, duplicate the file descriptor bound to the process’s STDOUT also to STDERR.
#   default value: false

# _bg:
#   use: Runs a command in the background. The command will return immediately, and you will
#        have to run RunningCommand#wait on it to ensure it terminates.
#   default value: false

# _timeout:
#   use: How much time, in seconds, we should give the process to complete. If the process
#        does not finish within the timeout, it will be terminated.
#   default value: nil

# _env:
#   use: A dictionary defining the only environment variables that will be made accessible to
#        the process. If not specified, the calling process’s environment variables are used.
#   default value: nil

# _cwd:
#   use: Current working directory of the process.
#   default value: nil
Rubsh.cmd('pwd').(_cwd: '/').stdout_data # => "/\n"
Rubsh.cmd('pwd').(_cwd: Pathname.new('/home')).stdout_data # => "/home\n"

# _ok_code:
#   use: Some misbehaved programs use exit codes other than 0 to indicate success. Set to treats
#        as success.
#   default value: [0]

# _in:
#   use: Specifies an argument for the process to use as its standard input.
#   default value: nil

# _no_out:
#   use: Disables STDOUT being internally stored. This is useful for commands that produce huge
#        amounts of output that you don’t need, that would otherwise be hogging memory if stored
#        internally by sh.
#   default value: false

# _no_err:
#   use: Disables STDERR being internally stored. This is useful for commands that produce huge
#        amounts of output that you don’t need, that would otherwise be hogging memory if stored
#        internally by sh.
#   default value: false

# _long_sep:
#   use: This is the character(s) that separate a program’s long argument’s key from the value.
#   default value: "="

# _long_prefix:
#   use: This is the character(s) that prefix a long argument for the program being run. Some
#        programs use single dashes, for example, and do not understand double dashes.
#   default value: "--"

# _pipeline:
#   use: Specifies the :pipeline.
#   default value: nil
```

### Special Kwargs - work with `Rubsh::RunningPipeline#call`

```ruby
# _out:
#   use: where to redirect STDOUT to.
#   default value: nil

# _in
#   use: Specifies an argument for the process to use as its standard input.
#   default value: nil
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/souk4711/rubsh. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/souk4711/rubsh/blob/main/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Code of Conduct

Everyone interacting in the Rubsh project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/souk4711/rubsh/blob/main/CODE_OF_CONDUCT.md).


[python-sh]:https://github.com/amoffat/sh
