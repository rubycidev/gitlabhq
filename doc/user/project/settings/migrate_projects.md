---
stage: Data Stores
group: Tenant Scale
info: 'To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments'
---

# Transfer projects

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** SaaS, self-managed

## Transfer a project to another namespace

When you transfer a project to another namespace, you move the project to a different group.

Prerequisites:

- You must have at least the Maintainer role for the [group](../../group/index.md#create-a-group) you are transferring to.
- You must be the Owner of the project you transfer.
- The group must allow creation of new projects.
- The project must not contain any [container images](../../packages/container_registry/index.md#move-or-rename-container-registry-repositories).
- The project must not have a security policy.
  If a security policy is assigned to the project, it is automatically unassigned during the transfer.
- If the root namespace changes, you must remove npm packages that follow the [naming convention](../../../user/packages/npm_registry/index.md#naming-convention) from the project.
  After you transfer the project you can either:

  - Update the package scope with the new root namespace path, and publish it again to the project.
  - Republish the package to the project without updating the root namespace path, which causes the package to no longer follow the naming convention.
    If you republish the package without updating the root namespace path, it will not be available at the [instance level endpoint](../../../user/packages/npm_registry/index.md#install-from-the-instance-level).

To transfer a project:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Settings > General**.
1. Expand **Advanced**.
1. Under **Transfer project**, choose the namespace to transfer the project to.
1. Select **Transfer project**.
1. Enter the project's name and select **Confirm**.

You are redirected to the project's new page and GitLab applies a redirect. For more information about repository redirects, see [What happens when a repository path changes](../repository/index.md#what-happens-when-a-repository-path-changes).

NOTE:
If you are an administrator, you can also use the [administration interface](../../../administration/admin_area.md#administering-projects)
to move any project to any namespace.

## Transferring a GitLab SaaS project to a different subscription tier

When you transfer a project from a namespace licensed for GitLab SaaS Premium or Ultimate to GitLab Free:

- [Project access tokens](../../../user/project/settings/project_access_tokens.md) are revoked.
- [Pipeline subscriptions](../../../ci/pipelines/index.md#trigger-a-pipeline-when-an-upstream-project-is-rebuilt)
  and [test cases](../../../ci/test_cases/index.md) are deleted.

## Troubleshooting

When working with project settings, you might encounter the following issues, or require alternate methods to complete specific tasks.

### Transfer a project through console

If transferring a project through the UI or API is not working, you can attempt the transfer in a [Rails console session](../../../administration/operations/rails_console.md#starting-a-rails-console-session).

```ruby
p = Project.find_by_full_path('<project_path>')

# To set the owner of the project
current_user = p.creator

# Namespace where you want this to be moved
namespace = Namespace.find_by_full_path("<new_namespace>")

Projects::TransferService.new(p, current_user).execute(namespace)
```

## Related topics

- [Migrating projects using file exports](import_export.md)
- [Troubleshooting file export project migrations](import_export_troubleshooting.md)
