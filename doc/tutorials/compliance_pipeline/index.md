---
stage: Govern
group: Compliance
info: For assistance with this tutorial, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-other-projects-and-subjects.
---

# Tutorial: Create a compliance pipeline

DETAILS:
**Tier:** Ultimate
**Offering:** SaaS, self-managed

You can use [compliance pipelines](../../user/group/compliance_pipelines.md) to ensure specific
compliance-related jobs are run on pipelines for all projects in a group. Compliance pipelines are applied
to projects through [compliance frameworks](../../user/group/compliance_frameworks.md).

In this tutorial, you:

1. Create a [new group](#create-a-new-group).
1. Create a [new project for the compliance pipeline configuration](#create-a-new-compliance-pipeline-project).
1. Configure a [compliance framework](#configure-compliance-framework) to apply to other projects.
1. Create a [new project and apply the compliance framework](#create-a-new-project-and-apply-the-compliance-framework) to it.
1. Combine [compliance pipeline configuration and regular pipeline configuration](#combine-pipeline-configurations).

## Before you begin

- You need permission to create new top-level groups.

## Create a new group

Compliance frameworks are configured in top-level groups. In this tutorial, you create a top-level group that:

- Contains two projects:
  - The compliance pipeline project to store the compliance pipeline configuration.
  - Another project that must run a job in its pipeline that is defined by the compliance pipeline configuration.
- Has the compliance framework to apply to projects.

To create the new group:

1. On the left sidebar, at the top, select **Create new** (**{plus}**) and **New group**.
1. Select **Create group**.
1. In the **Group name** field, enter `Tutorial group`.
1. Select **Create group**.

## Create a new compliance pipeline project

Now you're ready to create a compliance pipeline project. This project contains the
[compliance pipeline configuration](../../user/group/compliance_pipelines.md#example-configuration) to apply to all
projects with the compliance framework applied.

To create the compliance pipeline project:

1. On the left sidebar, select **Search or go to** and find the `Tutorial group` group.
1. Select **New project**.
1. Select **Create blank project**.
1. In the **Project name** field, enter `Tutorial compliance project`.
1. Select **Create project**.

To add compliance pipeline configuration to `Tutorial compliance project`:

1. On the left sidebar, select **Search or go to** and find the `Tutorial compliance project` project.
1. Select **Build > Pipeline editor**.
1. Select **Configure pipeline**.
1. In the pipeline editor, replace the default configuration with:

   ```yaml
   ---
   compliance-job:
     script:
       - echo "Running compliance job required for every project in this group..."
   ```

1. Select **Commit changes**.

## Configure compliance framework

The compliance framework is configured in the [new group](#create-a-new-group).

To configure the compliance framework:

1. On the left sidebar, select **Search or go to** and find the `Tutorial group` group.
1. Select **Settings > General**.
1. Expand **Compliance frameworks**.
1. Select **Add framework**.
1. In the **Name** field, enter `Tutorial compliance framework`.
1. In the **Description** field, enter `Compliance framework for tutorial`.
1. In the **Compliance pipeline configuration (optional)** field, enter
   `.gitlab-ci.yml@tutorial-group/tutorial-compliance-project`.
1. In the **Background color** field, select a color of your choice.
1. Select **Add framework**.

For convenience, make the new compliance framework the default for all new projects in the group:

1. On the left sidebar, select **Search or go to** and find the `Tutorial group` group.
1. Select **Settings > General**.
1. Expand **Compliance frameworks**.
1. In the row for `Tutorial compliance framework`, select **Options** (**{ellipsis_v}**).
1. Select **Set default**.

## Create a new project and apply the compliance framework

Your compliance framework is ready, so you can now create projects in the group and they automatically run the
compliance pipeline configuration in their pipelines.

To create a new project for running the compliance pipeline configuration:

1. On the left sidebar, select **Search or go to** and find the `Tutorial group` group.
1. Select **Create new** (**{plus}**) and **New project/repository**.
1. Select **Create blank project**.
1. In the **Project name** field, enter `Tutorial project`.
1. Select **Create project**.

On the project page, notice the `Tutorial compliance framework` label appears because that was set as the default
compliance framework for the group.

Without any other pipeline configuration, `Tutorial project` can run the jobs defined in the compliance
pipeline configuration in `Tutorial compliance project`.

To run the compliance pipeline configuration in `Tutorial project`:

1. On the left sidebar, select **Search or go to** and find the `Tutorial project` project.
1. Select **Build > Pipelines**.
1. Select **Run pipeline**.
1. On the **Run pipeline** page, select **Run pipeline**.

Notice the pipeline runs a job called `compliance-job` in a **test** stage. Nice work, you've run your first compliance
job!

## Combine pipeline configurations

If you want projects to run their own jobs as well as the compliance pipeline jobs, you must combine the compliance
pipeline configuration and the regular pipeline configuration of the project.

To combine the pipeline configurations, you must define the regular pipeline configuration and then update the
compliance pipeline configuration to refer to it.

To create the regular pipeline configuration:

1. On the left sidebar, select **Search or go to** and find the `Tutorial project` project.
1. Select **Build > Pipeline editor**.
1. Select **Configure pipeline**.
1. In the pipeline editor, replace the default configuration with:

   ```yaml
   ---
   project-job:
     script:
       - echo "Running project job..."
   ```

1. Select **Commit changes**.

To combine the new project pipeline configuration with the compliance pipeline configuration:

1. On the left sidebar, select **Search or go to** and find the `Tutorial compliance project` project.
1. Select **Build > Pipeline editor**.
1. In the existing configuration, add:

   ```yaml
   include:
     - project: 'tutorial-group/tutorial-project'
       file: '.gitlab-ci.yml'
    ```

1. Select **Commit changes**.

To confirm the regular pipeline configuration is combined with the compliance pipeline configuration:

1. On the left sidebar, select **Search or go to** and find the `Tutorial project` project.
1. Select **Build > Pipelines**.
1. Select **Run pipeline**.
1. On the **Run pipeline** page, select **Run pipeline**.

Notice the pipeline runs two jobs in a **test** stage:

- `compliance-job`.
- `project-job`.

Congratulations, you've created and configured a compliance pipeline!

See more [example compliance pipeline configurations](../../user/group/compliance_pipelines.md#example-configuration).
