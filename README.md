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
rcmd = Rubsh.cmd("ls").("/")
rcmd.exit_code # => 0

# a `CommandReturnFailureError` raised when run failure
begin
  Rubsh.cmd("ls").("/some/non-existant/folder")
rescue Rubsh::Exceptions::CommandReturnFailureError => e
  e.exit_code # => 2
end

# treat as success use `:_ok_code`
rcmd = Rubsh.cmd("ls").("/some/non-existant/folder", _ok_code: [0, 2])
rcmd.exit_code # => 2
```

### Redirection

```ruby
# NotImplementedError
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
# NotImplementedError
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
