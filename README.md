# terraform-google-managed-instance-group

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
zonal managed instance group (`google_compute_instance_group_manager`). It runs
a fixed number of instances from an instance template and exposes named ports
for load balancers.

## Usage

```hcl
module "mig" {
  source = "github.com/cybercapybara/terraform-google-managed-instance-group"

  project_id         = var.project_id
  name               = "web-mig"
  zone               = "us-central1-a"
  base_instance_name = "web"
  instance_template  = module.instance_template.self_link
  target_size        = 3

  named_ports = {
    http = 80
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                 | Description                                                    | Type          | Default | Required |
|----------------------|----------------------------------------------------------------|---------------|---------|:--------:|
| `project_id`         | ID of the project in which to create the group.                | `string`      | n/a     |   yes    |
| `name`               | Name of the managed instance group.                            | `string`      | n/a     |   yes    |
| `zone`               | Zone in which to create the group.                             | `string`      | n/a     |   yes    |
| `base_instance_name` | Base name used to generate instance names.                     | `string`      | n/a     |   yes    |
| `instance_template`  | Self link of the instance template.                            | `string`      | n/a     |   yes    |
| `target_size`        | Target number of running instances.                            | `number`      | `2`     |    no    |
| `named_ports`        | Named ports exposed by the group, keyed by name.               | `map(number)` | `{}`    |    no    |
| `description`        | Optional description for the group.                            | `string`      | `null`  |    no    |

## Outputs

| Name             | Description                                          |
|------------------|------------------------------------------------------|
| `id`             | Identifier of the managed instance group.           |
| `self_link`      | URI of the managed instance group.                  |
| `instance_group` | Self link of the underlying instance group.         |

## License

[MIT](LICENSE)
