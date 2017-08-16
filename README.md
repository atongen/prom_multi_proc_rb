# prom_multi_proc_rb

[![Build Status](https://travis-ci.org/atongen/prom_multi_proc_rb.svg?branch=master)](https://travis-ci.org/atongen/prom_multi_proc_rb)

Ruby client library for collecting prometheus metrics.
Designed for use in applications running under forking servers (unicorn, puma).
Writes metrics in json format to unix socket being listened to
by [prom_multi_proc](https://github.com/atongen/prom_multi_proc).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'prom_multi_proc_rb', require: 'prom_multi_proc'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install prom_multi_proc_rb

## General Usage

### Define metrics

Create a json file to define the prometheus metrics that your application will track, for example:

```json
[
    {
        "type": "counter",
        "name": "app_test_counter_total",
        "help": "A test counter",
        "labels": [
            "label1",
        ]
    },
    {
        "type": "gauge",
        "name": "app_test_gauge_total",
        "help": "A test gauge",
        "labels": [
            "label2",
        ]
    },
    {
        "type": "histogram",
        "name": "app_test_histogram_seconds",
        "help": "A test histogram",
        "labels": [
            "label3",
        ]
    },
    {
        "type": "summary",
        "name": "app_test_summary_seconds",
        "help": "A test summary",
        "labels": [
            "label4",
        ]
    }
]
```

This file is intened to be shared by both the aggregator process and this ruby library.

### Install and start the aggregator process

Download, install, and start the [prom_multi_proc](https://github.com/atongen/prom_multi_proc)
aggregator application using the metrics json definition file created earlier.
Make note of the socket location.

Note that in development, the ruby client will funtion normally if there is no aggregator process listening
on the socket.

### Collect metrics in ruby app

Create a `PromMultiProc::Base` object for collecting metrics
and begin collecting metrics:

```ruby
metrics = PromMultiProc::Base.new(
  prefix: "app_",
  socket: "path/to/aggregator/socket.sock",
  metrics: "path/to/metrics/definition.json",
  batch_size: 10,
  validate: true
)

metrics.test_counter_total.inc(label1: "my-label-value")
metrics.test_histogram_seconds.observe(2.3, label3: "my-other-label-value")
```

## Rails Usage

This helper class can be used to simplify a rails initializer, for example, in `config/initializers/prom_multi_proc.rb`:

```ruby
$prom_multi_proc = PromMultiProc::Rails.init

$prom_multi_proc.test_counter_total.inc(label1: "my-label-value")
$prom_multi_proc.test_histogram_seconds.observe(2.3, label3: "my-other-label-value")
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atongen/prom_multi_proc_rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the prom_multi_proc_rb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/atongen/prom_multi_proc_rb/blob/master/CODE_OF_CONDUCT.md).
