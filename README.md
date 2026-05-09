# prom_multi_proc_rb

[![CI](https://github.com/atongen/prom_multi_proc_rb/actions/workflows/ci.yml/badge.svg)](https://github.com/atongen/prom_multi_proc_rb/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/prom_multi_proc_rb.svg)](https://badge.fury.io/rb/prom_multi_proc_rb)

Ruby client library for collecting Prometheus metrics in multi-process applications.
Designed for forking servers (Unicorn, Puma). Writes metrics as JSON to a Unix socket
listened to by [prom_multi_proc](https://github.com/atongen/prom_multi_proc).

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

Create a JSON file to define the Prometheus metrics your application will track:

```json
[
    {
        "type": "counter",
        "name": "app_requests_total",
        "help": "Total HTTP requests",
        "labels": ["method", "status"]
    },
    {
        "type": "gauge",
        "name": "app_workers_active",
        "help": "Number of active workers"
    },
    {
        "type": "histogram",
        "name": "app_request_duration_seconds",
        "help": "Request duration in seconds",
        "labels": ["method"]
    },
    {
        "type": "summary",
        "name": "app_response_size_bytes",
        "help": "Response size in bytes",
        "labels": ["method"]
    }
]
```

This file is shared by both the aggregator process and the Ruby client. Metric names
in the JSON file may or may not include the prefix — the client applies it automatically
if it is missing.

### Install and start the aggregator process

Download, install, and start [prom_multi_proc](https://github.com/atongen/prom_multi_proc)
using the metrics JSON definition file. Note the socket path.

The Ruby client functions normally if no aggregator is listening on the socket — failed
writes are logged and silently dropped so the host application is never interrupted.

### Collect metrics

Create a `PromMultiProc::Base` object and begin recording metrics:

```ruby
metrics = PromMultiProc::Base.new(
  prefix:     "app_",
  socket:     "/var/run/prom_multi_proc/metrics.sock",
  metrics:    "/etc/myapp/metrics.json",
  batch_size: 10,
  validate:   true
)

metrics.requests_total.inc(method: "GET", status: "200")
metrics.request_duration_seconds.observe(0.042, method: "GET")
```

#### Configuration options

| Option | Default | Description |
|---|---|---|
| `socket:` | _(required)_ | Path to the Unix socket of the aggregator daemon |
| `metrics:` | _(required)_ | Path to the JSON metric definition file |
| `prefix:` | `""` | Metric name prefix. Applied to names in the spec that don't already carry it. |
| `batch_size:` | `1` | Flush after accumulating this many messages. |
| `batch_timeout:` | `3` | Force-flush every N seconds even if batch is not full. |
| `validate:` | `false` | Raise `PromMultiProcError` on invalid labels/values instead of silently dropping |

#### Prefix behavior

The `prefix:` option works the same way as the `-metric-prefix` flag on the aggregator server:
if a metric name in the JSON spec already starts with the prefix, it is used as-is; otherwise
the prefix is prepended. This means you can use either full names or short names in your spec file.

```ruby
# Both of these result in wire name "app_requests_total":
# spec: {"name": "app_requests_total", ...}  → already has prefix, used as-is
# spec: {"name": "requests_total", ...}       → prefix applied → "app_requests_total"
```

#### Multi / batch writes

Use `#multi` to record multiple metrics in a single atomic socket write:

```ruby
metrics.multi do |m|
  m.requests_total.inc(method: "POST", status: "201")
  m.workers_active.set(8)
  m.request_duration_seconds.observe(0.015, method: "POST")
end
```

## Rails Usage

A Rails initializer helper is provided at `PromMultiProc::Rails.init`.
Create `config/initializers/prom_multi_proc.rb`:

```ruby
$prom = PromMultiProc::Rails.init

$prom.requests_total.inc(method: "GET", status: "200")
$prom.request_duration_seconds.observe(0.042, method: "GET")
```

`Rails.init` derives sensible defaults from the Rails environment (batch size, validate, socket
path, etc.) and accepts keyword arguments to override any of them:

```ruby
# Override prefix and bump batch size in production
$prom = PromMultiProc::Rails.init(prefix: "myapp_", batch_size: 50)

# Point at a non-default socket
$prom = PromMultiProc::Rails.init(socket: "/run/metrics/custom.sock")
```

The `PROM_MULTI_PROC_SOCKET` and `PROM_MULTI_PROC_DEFINITION_FILE` environment variables are
still respected as fallback defaults for `socket:` and `metrics:`, but any value passed directly
as a keyword argument takes precedence.

## Wire format

Each flush sends a JSON array over the Unix socket and then closes the connection:

```json
[
  {"name":"app_requests_total","method":"inc","value":1.0,"label_values":["GET","200"]},
  {"name":"app_workers_active","method":"set","value":8.0,"label_values":[]}
]
```

## Metric types and methods

| Type | Methods |
|---|---|
| `counter` | `inc`, `add` |
| `gauge` | `set`, `inc`, `dec`, `add`, `sub`, `set_to_current_time` |
| `histogram` | `observe` |
| `summary` | `observe` |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atongen/prom_multi_proc_rb.

## License

Available as open source under the [MIT License](http://opensource.org/licenses/MIT).
