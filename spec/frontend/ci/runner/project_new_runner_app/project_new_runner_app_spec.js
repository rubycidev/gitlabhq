import { GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { s__ } from '~/locale';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert, VARIANT_SUCCESS } from '~/alert';

import ProjectRunnerRunnerApp from '~/ci/runner/project_new_runner/project_new_runner_app.vue';
import RegistrationCompatibilityAlert from '~/ci/runner/components/registration/registration_compatibility_alert.vue';
import { saveAlertToLocalStorage } from '~/ci/runner/local_storage_alert/save_alert_to_local_storage';
import RunnerPlatformsRadioGroup from '~/ci/runner/components/runner_platforms_radio_group.vue';
import {
  PARAM_KEY_PLATFORM,
  PROJECT_TYPE,
  DEFAULT_PLATFORM,
  WINDOWS_PLATFORM,
  GOOGLE_CLOUD_PLATFORM,
} from '~/ci/runner/constants';
import RunnerCloudConnectionForm from '~/ci/runner/components/runner_cloud_connection_form.vue';
import RunnerCloudExecutionEnvironment from '~/ci/runner/components/runner_cloud_execution_environment.vue';
import RunnerCreateForm from '~/ci/runner/components/runner_create_form.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import { runnerCreateResult, mockRegistrationToken } from '../mock_data';

const mockProjectId = 'gid://gitlab/Project/72';

jest.mock('~/ci/runner/local_storage_alert/save_alert_to_local_storage');
jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

const mockCreatedRunner = runnerCreateResult.data.runnerCreate.runner;

describe('ProjectRunnerRunnerApp', () => {
  let wrapper;

  const findRunnerPlatformsRadioGroup = () => wrapper.findComponent(RunnerPlatformsRadioGroup);
  const findRegistrationCompatibilityAlert = () =>
    wrapper.findComponent(RegistrationCompatibilityAlert);
  const findRunnerCreateForm = () => wrapper.findComponent(RunnerCreateForm);
  const findRunnerCloudForm = () => wrapper.findComponent(RunnerCloudConnectionForm);
  const findRunnerCloudExecutionEnvironment = () =>
    wrapper.findComponent(RunnerCloudExecutionEnvironment);

  const createComponent = (gcpRunner = false) => {
    wrapper = shallowMountExtended(ProjectRunnerRunnerApp, {
      propsData: {
        projectId: mockProjectId,
        legacyRegistrationToken: mockRegistrationToken,
      },
      stubs: {
        GlSprintf,
      },
      provide: {
        glFeatures: {
          gcpRunner,
        },
      },
    });
  };

  describe('defaults', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows a registration compatibility alert', () => {
      expect(findRegistrationCompatibilityAlert().props('alertKey')).toBe(mockProjectId);
    });

    describe('Platform', () => {
      it('shows the platforms radio group', () => {
        expect(findRunnerPlatformsRadioGroup().props('value')).toBe(DEFAULT_PLATFORM);
      });
    });

    describe('Runner form', () => {
      it('shows the runner create form for an instance runner', () => {
        expect(findRunnerCreateForm().props()).toEqual({
          runnerType: PROJECT_TYPE,
          projectId: mockProjectId,
          groupId: null,
        });
      });

      describe('When a runner is saved', () => {
        beforeEach(() => {
          findRunnerCreateForm().vm.$emit('saved', mockCreatedRunner);
        });

        it('pushes an alert to be shown after redirection', () => {
          expect(saveAlertToLocalStorage).toHaveBeenCalledWith({
            message: s__('Runners|Runner created.'),
            variant: VARIANT_SUCCESS,
          });
        });

        it('redirects to the registration page', () => {
          const url = `${mockCreatedRunner.ephemeralRegisterUrl}?${PARAM_KEY_PLATFORM}=${DEFAULT_PLATFORM}`;

          expect(visitUrl).toHaveBeenCalledWith(url);
        });
      });

      describe('When another platform is selected and a runner is saved', () => {
        beforeEach(() => {
          findRunnerPlatformsRadioGroup().vm.$emit('input', WINDOWS_PLATFORM);
          findRunnerCreateForm().vm.$emit('saved', mockCreatedRunner);
        });

        it('redirects to the registration page with the platform', () => {
          const url = `${mockCreatedRunner.ephemeralRegisterUrl}?${PARAM_KEY_PLATFORM}=${WINDOWS_PLATFORM}`;

          expect(visitUrl).toHaveBeenCalledWith(url);
        });
      });

      describe('When runner fails to save', () => {
        const ERROR_MSG = 'Cannot save!';

        beforeEach(() => {
          findRunnerCreateForm().vm.$emit('error', new Error(ERROR_MSG));
        });

        it('shows an error message', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: ERROR_MSG });
        });
      });
    });
  });

  describe('Runner cloud form', () => {
    it.each`
      flagState | visible
      ${true}   | ${true}
      ${false}  | ${false}
    `(
      'shows runner cloud form: $visible when flag is set to $flagState and platform is google',
      async ({ flagState, visible }) => {
        createComponent(flagState);

        findRunnerPlatformsRadioGroup().vm.$emit('input', GOOGLE_CLOUD_PLATFORM);

        await nextTick();

        expect(findRunnerCloudForm().exists()).toBe(visible);
      },
    );

    describe('Execution environment', () => {
      beforeEach(async () => {
        createComponent(true);

        findRunnerPlatformsRadioGroup().vm.$emit('input', GOOGLE_CLOUD_PLATFORM);

        await nextTick();
      });

      it('should display the cloud execution environment form', async () => {
        findRunnerCloudForm().vm.$emit('continue');

        await nextTick();

        expect(findRunnerCloudExecutionEnvironment().exists()).toBe(true);
      });
    });
  });
});
