# terraform-google-managed-instance-group

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
zonal managed instance group (`google_compute_instance_group_manager`). It runs
instances from an instance template, exposes named ports for load balancers, and
optionally configures auto-healing and a rolling update policy.

## Usage

```hcl
resource "google_compute_health_check" "web" {
  name = "web-health"

  http_health_check {
    port         = 80
    request_path = "/healthz"
  }
}

module "mig" {
  source = "github.com/moveeeax/terraform-google-managed-instance-group"

  project_id         = var.project_id
  name               = "web-mig"
  zone               = "us-central1-a"
  base_instance_name = "web"
  instance_template  = module.instance_template.self_link
  target_size        = 3

  named_ports = {
    http = 80
  }

  auto_healing_policy = {
    health_check      = google_compute_health_check.web.self_link
    initial_delay_sec = 300
  }

  update_policy = {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 0
  }
}
```

Runnable examples live in [`examples/basic`](examples/basic) (fixed size behind a
backend service) and [`examples/autoscaled`](examples/autoscaled) (size owned by
an autoscaler).

## Operational notes

These are the failure modes the module actively guards against. They are worth
understanding before overriding anything.

**Auto-healing needs a health check, and a long enough grace period.**
`auto_healing_policy` is off by default. Left off, the group only recreates
instances that Compute Engine itself considers gone; an application that has hung
while its VM stays up is never replaced. When you enable it, `health_check` is a
required attribute — healing without a health signal is not a thing the module
will construct. `initial_delay_sec` (default `300`) is how long a new or
recreated instance is exempt from healing, and it must comfortably exceed boot
plus application warm-up. Set it too low and the group kills instances that are
still starting, then kills their replacements, and never converges.

**A proactive rollout requires a health signal.** `update_policy.type =
"PROACTIVE"` makes the group roll a new instance template across every existing
instance on its own. The module rejects that combination unless
`auto_healing_policy` is also set, because an automatic rollout with nothing
watching will replace the entire group with a broken image unnoticed. With
`OPPORTUNISTIC`, existing instances are only updated when something else
recreates them. Omitting `update_policy` entirely keeps the Compute Engine
default, under which a template change only affects instances created afterwards.

**`minimal_action` and `most_disruptive_allowed_action` must be coherent.** They
are a floor and a ceiling over `NONE < REFRESH < RESTART < REPLACE`. If the
ceiling sits below the floor, the updater silently declines to update anything
rather than erroring, so the module rejects it up front. Similarly, an update
policy that pins both `max_surge` and `max_unavailable` to zero leaves a rolling
update no room to replace anything and hangs forever; that is rejected too.

**`target_size` and autoscalers are mutually exclusive.** If a
`google_compute_autoscaler` targets this group, set `target_size = null`.
Otherwise Terraform and the autoscaler both claim ownership of the instance
count, every plan shows a spurious resize, and applies undo the autoscaler's
work.

**Named ports must match what the backend service selects.** A
`google_compute_backend_service` whose `port_name` is not declared by this group
produces no error at all — just a backend that never passes health checks. Drive
both from one value, and use the `named_ports` output to assert the wiring rather
than repeating a string literal; `examples/basic` shows the pattern.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

The test suite under `tests/` additionally needs Terraform or OpenTofu >= 1.7 for
`mock_provider`. That is a contributor-only requirement; consumers of the module
still only need 1.5.

## Inputs

| Name                  | Description                                                                    | Type          | Default | Required |
|-----------------------|--------------------------------------------------------------------------------|---------------|---------|:--------:|
| `project_id`          | ID of the project in which to create the group.                                | `string`      | n/a     |   yes    |
| `name`                | Name of the managed instance group.                                            | `string`      | n/a     |   yes    |
| `zone`                | Zone in which to create the group.                                             | `string`      | n/a     |   yes    |
| `base_instance_name`  | Base name used to generate instance names.                                     | `string`      | n/a     |   yes    |
| `instance_template`   | Self link of the instance template.                                            | `string`      | n/a     |   yes    |
| `target_size`         | Target number of running instances. `null` hands ownership to an autoscaler.   | `number`      | `2`     |    no    |
| `named_ports`         | Named ports exposed by the group, keyed by name.                               | `map(number)` | `{}`    |    no    |
| `description`         | Optional description for the group.                                            | `string`      | `null`  |    no    |
| `auto_healing_policy` | Auto-healing policy; `null` disables auto-healing.                             | `object`      | `null`  |    no    |
| `update_policy`       | Rolling update policy; `null` keeps the Compute Engine default.                | `object`      | `null`  |    no    |

### `auto_healing_policy`

| Attribute           | Type     | Default | Notes                                                       |
|---------------------|----------|---------|-------------------------------------------------------------|
| `health_check`      | `string` | n/a     | Required. Self link of a `google_compute_health_check`.     |
| `initial_delay_sec` | `number` | `300`   | 0–3600. Must exceed boot plus application warm-up.          |

### `update_policy`

| Attribute                        | Type     | Default | Notes                                                     |
|----------------------------------|----------|---------|-----------------------------------------------------------|
| `type`                           | `string` | n/a     | Required. `PROACTIVE` or `OPPORTUNISTIC`.                 |
| `minimal_action`                 | `string` | n/a     | Required. `NONE`, `REFRESH`, `RESTART` or `REPLACE`.      |
| `most_disruptive_allowed_action` | `string` | `null`  | Same set; must not be below `minimal_action`.             |
| `replacement_method`             | `string` | `null`  | `RECREATE` (needs `max_unavailable` > 0) or `SUBSTITUTE`. |
| `max_surge_fixed`                | `number` | `null`  | Conflicts with `max_surge_percent`.                       |
| `max_surge_percent`              | `number` | `null`  | 0–100. Conflicts with `max_surge_fixed`.                  |
| `max_unavailable_fixed`          | `number` | `null`  | Conflicts with `max_unavailable_percent`.                 |
| `max_unavailable_percent`        | `number` | `null`  | 0–100. Conflicts with `max_unavailable_fixed`.            |

## Outputs

| Name             | Description                                                         |
|------------------|---------------------------------------------------------------------|
| `id`             | Identifier of the managed instance group.                           |
| `self_link`      | URI of the managed instance group.                                  |
| `instance_group` | Self link of the underlying instance group.                         |
| `named_ports`    | Named ports actually declared on the group, keyed by port name.     |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test          # needs Terraform >= 1.7; runs offline against a mock provider
tflint --recursive
```

## License

[MIT](LICENSE)
