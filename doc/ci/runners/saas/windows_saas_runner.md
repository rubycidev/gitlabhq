---
stage: Verify
group: Runner
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# SaaS runners on Windows

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** SaaS
**Status:** Beta

SaaS runner on Windows autoscale by launching virtual machines on
the Google Cloud Platform. This solution uses an
[autoscaling driver](https://gitlab.com/gitlab-org/ci-cd/custom-executor-drivers/autoscaler/-/blob/main/docs/README.md)
developed by GitLab for the [custom executor](https://docs.gitlab.com/runner/executors/custom.html).
SaaS runners on Windows are in [Beta](../../../policy/experiment-beta-support.md#beta)
and aren't recommended for production workloads.

We want to keep iterating to get Windows runners in a stable state and
[generally available](../../../policy/experiment-beta-support.md#generally-available-ga).
You can follow our work towards this goal in the
[related epic](https://gitlab.com/groups/gitlab-org/-/epics/2162).

## Machine types available for Windows

| Runner Tag                  | vCPUs | Memory | Storage |
| --------------------------- | ----- | ------ | ------- |
| `saas-windows-medium-amd64` | 2     | 7.5 GB | 75 GB   |

## Supported Windows versions

The Windows runner virtual machine instances do not use the GitLab Docker executor. This means that you can't specify
[`image`](../../../ci/yaml/index.md#image) or [`services`](../../../ci/yaml/index.md#services) in your pipeline configuration.

You can execute your job in one of the following Windows versions:

| Version      | Status        |
|--------------|---------------|
| Windows 2022 | `Beta`        |
| Windows 2019 | `Deprecated` (Removal in 17.0) |

You can find a full list of available pre-installed software in
the [pre-installed software documentation](https://gitlab.com/gitlab-org/ci-cd/shared-runners/images/gcp/windows-containers/blob/main/cookbooks/preinstalled-software/README.md).

NOTE:
We are only supporting a single version of Windows at this time.

## Supported shell

SaaS runners on Windows have PowerShell configured as the shell.
The `script` section of your `.gitlab-ci.yml` file therefore requires PowerShell commands.

## Example `.gitlab-ci.yml` file

Below is a sample `.gitlab-ci.yml` file that shows how to start using the runners for Windows:

```yaml
.windows_job:
  tags:
    - saas-windows-medium-amd64
  before_script:
    - Set-Variable -Name "time" -Value (date -Format "%H:%m")
    - echo ${time}
    - echo "started by ${GITLAB_USER_NAME}"

build:
  extends:
    - .windows_job
  stage: build
  script:
    - echo "running scripts in the build job"

test:
  extends:
    - .windows_job
  stage: test
  script:
    - echo "running scripts in the test job"
```

## Known issues

- For more information about support for Beta features, see [Beta](../../../policy/experiment-beta-support.md#beta).
- The average provisioning time for a new Windows virtual machine (VM) is five minutes, so
  you might notice slower start times for builds on the Windows runner
  fleet during the Beta. Updating the autoscaler to enable the pre-provisioning
  of virtual machines is proposed in a future release. This update is intended to
  significantly reduce the time it takes to provision a VM on the Windows fleet.
  For more information, see [issue 32](https://gitlab.com/gitlab-org/ci-cd/custom-executor-drivers/autoscaler/-/issues/32).
- The Windows runner fleet may be unavailable occasionally
  for maintenance or updates.
- The job may stay in a pending state for longer than the
  Linux runners.
- There is the possibility that we introduce breaking changes which will
  require updates to pipelines that are using the Windows runner
  fleet.
