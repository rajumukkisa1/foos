<script>
import {
  GlForm,
  GlIcon,
  GlLink,
  GlButton,
  GlSprintf,
  GlAlert,
  GlModal,
  GlModalDirective,
} from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import csrf from '~/lib/utils/csrf';
import { setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import MarkdownField from '~/vue_shared/components/markdown/field.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  CONTENT_EDITOR_LOADED_ACTION,
  SAVED_USING_CONTENT_EDITOR_ACTION,
  WIKI_CONTENT_EDITOR_TRACKING_LABEL,
  WIKI_FORMAT_LABEL,
  WIKI_FORMAT_UPDATED_ACTION,
} from '../constants';

const trackingMixin = Tracking.mixin({
  label: WIKI_CONTENT_EDITOR_TRACKING_LABEL,
});

const MARKDOWN_LINK_TEXT = {
  markdown: '[Link Title](page-slug)',
  rdoc: '{Link title}[link:page-slug]',
  asciidoc: 'link:page-slug[Link title]',
  org: '[[page-slug]]',
};

export default {
  i18n: {
    title: {
      label: s__('WikiPage|Title'),
      placeholder: s__('WikiPage|Page title'),
      helpText: {
        existingPage: s__(
          'WikiPage|Tip: You can move this page by adding the path to the beginning of the title.',
        ),
        newPage: s__(
          'WikiPage|Tip: You can specify the full path for the new file. We will automatically create any missing directories.',
        ),
        learnMore: s__('WikiPage|Learn more.'),
      },
    },
    format: {
      label: s__('WikiPage|Format'),
    },
    content: {
      label: s__('WikiPage|Content'),
      placeholder: s__('WikiPage|Write your content or drag files here…'),
    },
    contentEditor: {
      renderFailed: {
        message: s__(
          'WikiPage|An error occured while trying to render the content editor. Please try again later.',
        ),
        primaryAction: s__('WikiPage|Retry'),
      },
      useNewEditor: {
        primaryLabel: s__('WikiPage|Use the new editor'),
        secondaryLabel: s__('WikiPage|Try this later'),
        title: s__('WikiPage|Get a richer editing experience'),
        text: s__(
          "WikiPage|Try the new visual Markdown editor. Read the %{linkStart}documentation%{linkEnd} to learn what's currently supported.",
        ),
      },
      switchToOldEditor: {
        label: s__('WikiPage|Switch me back to the classic editor.'),
        helpText: s__(
          "WikiPage|This editor is in beta and may not display the page's contents properly. Switching back to the classic editor will discard changes you've made in the new editor.",
        ),
        modal: {
          title: s__('WikiPage|Are you sure you want to switch back to the classic editor?'),
          primary: s__('WikiPage|Switch to classic editor'),
          cancel: s__('WikiPage|Keep editing'),
          text: s__(
            "WikiPage|Switching to the classic editor will discard any changes you've made in the new editor.",
          ),
        },
      },
      feedbackTip: __(
        'Tell us your experiences with the new Markdown editor %{linkStart}in this feedback issue%{linkEnd}.',
      ),
    },
    linksHelpText: s__(
      'WikiPage|To link to a (new) page, simply type %{linkExample}. More examples are in the %{linkStart}documentation%{linkEnd}.',
    ),
    commitMessage: {
      label: s__('WikiPage|Commit message'),
      value: {
        existingPage: s__('WikiPage|Update %{pageTitle}'),
        newPage: s__('WikiPage|Create %{pageTitle}'),
      },
    },
    submitButton: {
      existingPage: s__('WikiPage|Save changes'),
      newPage: s__('WikiPage|Create page'),
    },
    cancel: s__('WikiPage|Cancel'),
    editSourceButtonText: s__('WikiPage|Edit source'),
    editRichTextButtonText: s__('WikiPage|Edit rich text'),
  },
  contentEditorFeedbackIssue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/332629',
  components: {
    GlAlert,
    GlForm,
    GlSprintf,
    GlIcon,
    GlLink,
    GlButton,
    GlModal,
    MarkdownField,
    ContentEditor: () =>
      import(
        /* webpackChunkName: 'content_editor' */ '~/content_editor/components/content_editor.vue'
      ),
  },
  directives: {
    GlModalDirective,
  },
  mixins: [trackingMixin, glFeatureFlagMixin()],
  inject: ['formatOptions', 'pageInfo'],
  data() {
    return {
      title: this.pageInfo.title?.trim() || '',
      format: this.pageInfo.format || 'markdown',
      content: this.pageInfo.content || '',
      isContentEditorAlertDismissed: false,
      useContentEditor: false,
      commitMessage: '',
      isDirty: false,
      contentEditorRenderFailed: false,
      contentEditorEmpty: false,
    };
  },
  computed: {
    noContent() {
      if (this.isContentEditorActive) return this.contentEditorEmpty;
      return !this.content.trim();
    },
    csrfToken() {
      return csrf.token;
    },
    formAction() {
      return this.pageInfo.persisted ? this.pageInfo.path : this.pageInfo.createPath;
    },
    helpPath() {
      return setUrlFragment(
        this.pageInfo.helpPath,
        this.pageInfo.persisted ? 'move-a-wiki-page' : 'create-a-new-wiki-page',
      );
    },
    commitMessageI18n() {
      return this.pageInfo.persisted
        ? this.$options.i18n.commitMessage.value.existingPage
        : this.$options.i18n.commitMessage.value.newPage;
    },
    linkExample() {
      return MARKDOWN_LINK_TEXT[this.format];
    },
    toggleEditingModeButtonText() {
      return this.isContentEditorActive
        ? this.$options.i18n.editSourceButtonText
        : this.$options.i18n.editRichTextButtonText;
    },
    submitButtonText() {
      return this.pageInfo.persisted
        ? this.$options.i18n.submitButton.existingPage
        : this.$options.i18n.submitButton.newPage;
    },
    titleHelpText() {
      return this.pageInfo.persisted
        ? this.$options.i18n.title.helpText.existingPage
        : this.$options.i18n.title.helpText.newPage;
    },
    cancelFormPath() {
      if (this.pageInfo.persisted) return this.pageInfo.path;
      return this.pageInfo.wikiPath;
    },
    wikiSpecificMarkdownHelpPath() {
      return setUrlFragment(this.pageInfo.markdownHelpPath, 'wiki-specific-markdown');
    },
    contentEditorHelpPath() {
      return setUrlFragment(this.pageInfo.helpPath, 'gitlab-flavored-markdown-support');
    },
    isMarkdownFormat() {
      return this.format === 'markdown';
    },
    showContentEditorAlert() {
      return (
        !this.glFeatures.wikiSwitchBetweenContentEditorRawMarkdown &&
        this.isMarkdownFormat &&
        !this.useContentEditor &&
        !this.isContentEditorAlertDismissed
      );
    },
    showSwitchEditingModeButton() {
      return this.glFeatures.wikiSwitchBetweenContentEditorRawMarkdown && this.isMarkdownFormat;
    },
    displayWikiSpecificMarkdownHelp() {
      return !this.isContentEditorActive;
    },
    displaySwitchBackToClassicEditorMessage() {
      return (
        !this.glFeatures.wikiSwitchBetweenContentEditorRawMarkdown && this.isContentEditorActive
      );
    },
    disableSubmitButton() {
      return this.noContent || !this.title || this.contentEditorRenderFailed;
    },
    isContentEditorActive() {
      return this.isMarkdownFormat && this.useContentEditor;
    },
  },
  mounted() {
    this.updateCommitMessage();

    window.addEventListener('beforeunload', this.onPageUnload);
  },
  destroyed() {
    window.removeEventListener('beforeunload', this.onPageUnload);
  },
  methods: {
    renderMarkdown(content) {
      return axios
        .post(this.pageInfo.markdownPreviewPath, { text: content })
        .then(({ data }) => data.body);
    },

    toggleEditingMode() {
      if (this.useContentEditor) {
        this.content = this.contentEditor.getSerializedContent();
      }

      this.useContentEditor = !this.useContentEditor;
    },

    async handleFormSubmit(e) {
      e.preventDefault();

      if (this.useContentEditor) {
        this.content = this.contentEditor.getSerializedContent();

        this.trackFormSubmit();
      }

      this.trackWikiFormat();

      // Wait until form field values are refreshed
      await this.$nextTick();

      e.target.submit();

      this.isDirty = false;
    },

    handleContentChange() {
      this.isDirty = true;
    },

    async loadInitialContent(contentEditor) {
      this.contentEditor = contentEditor;

      try {
        await this.contentEditor.setSerializedContent(this.content);
        this.trackContentEditorLoaded();
      } catch (e) {
        this.contentEditorRenderFailed = true;
      }
    },

    async retryInitContentEditor() {
      try {
        this.contentEditorRenderFailed = false;
        await this.contentEditor.setSerializedContent(this.content);
      } catch (e) {
        this.contentEditorRenderFailed = true;
      }
    },

    handleContentEditorChange({ empty }) {
      this.contentEditorEmpty = empty;
      // TODO: Implement a precise mechanism to detect changes in the Content
      this.isDirty = true;
    },

    onPageUnload(event) {
      if (!this.isDirty) return undefined;

      event.preventDefault();

      // eslint-disable-next-line no-param-reassign
      event.returnValue = '';
      return '';
    },

    updateCommitMessage() {
      if (!this.title) return;

      // Replace hyphens with spaces
      const newTitle = this.title.replace(/-+/g, ' ');

      const newCommitMessage = sprintf(this.commitMessageI18n, { pageTitle: newTitle }, false);
      this.commitMessage = newCommitMessage;
    },

    initContentEditor() {
      this.useContentEditor = true;
    },

    switchToOldEditor() {
      this.useContentEditor = false;
    },

    confirmSwitchToOldEditor() {
      if (this.contentEditorRenderFailed) {
        this.contentEditorRenderFailed = false;
        this.switchToOldEditor();
      } else {
        this.$refs.confirmSwitchToOldEditorModal.show();
      }
    },

    trackContentEditorLoaded() {
      this.track(CONTENT_EDITOR_LOADED_ACTION);
    },

    trackFormSubmit() {
      if (this.isContentEditorActive) {
        this.track(SAVED_USING_CONTENT_EDITOR_ACTION);
      }
    },

    trackWikiFormat() {
      this.track(WIKI_FORMAT_UPDATED_ACTION, {
        label: WIKI_FORMAT_LABEL,
        extra: {
          project_path: this.pageInfo.path,
          old_format: this.pageInfo.format,
          value: this.format,
        },
      });
    },

    dismissContentEditorAlert() {
      this.isContentEditorAlertDismissed = true;
    },
  },
};
</script>

<template>
  <gl-form
    :action="formAction"
    method="post"
    class="wiki-form common-note-form gl-mt-3 js-quick-submit"
    @submit="handleFormSubmit"
  >
    <gl-alert
      v-if="isContentEditorActive && contentEditorRenderFailed"
      class="gl-mb-6"
      :dismissible="false"
      variant="danger"
      :primary-button-text="$options.i18n.contentEditor.renderFailed.primaryAction"
      @primaryAction="retryInitContentEditor"
    >
      {{ $options.i18n.contentEditor.renderFailed.message }}
    </gl-alert>

    <input :value="csrfToken" type="hidden" name="authenticity_token" />
    <input v-if="pageInfo.persisted" type="hidden" name="_method" value="put" />
    <input
      :v-if="pageInfo.persisted"
      type="hidden"
      name="wiki[last_commit_sha]"
      :value="pageInfo.lastCommitSha"
    />
    <div class="form-group row">
      <div class="col-sm-2 col-form-label">
        <label class="control-label-full-width" for="wiki_title">{{
          $options.i18n.title.label
        }}</label>
      </div>
      <div class="col-sm-10">
        <input
          id="wiki_title"
          v-model="title"
          name="wiki[title]"
          type="text"
          class="form-control"
          data-qa-selector="wiki_title_textbox"
          :required="true"
          :autofocus="!pageInfo.persisted"
          :placeholder="$options.i18n.title.placeholder"
          @input="updateCommitMessage"
        />
        <span class="gl-display-inline-block gl-max-w-full gl-mt-2 gl-text-gray-600">
          <gl-icon class="gl-mr-n1" name="bulb" />
          {{ titleHelpText }}
          <gl-link :href="helpPath" target="_blank">
            {{ $options.i18n.title.helpText.learnMore }}
          </gl-link>
        </span>
      </div>
    </div>
    <div class="form-group row">
      <div class="col-sm-2 col-form-label">
        <label class="control-label-full-width" for="wiki_format">{{
          $options.i18n.format.label
        }}</label>
      </div>
      <div class="col-sm-10">
        <select
          id="wiki_format"
          v-model="format"
          class="form-control"
          name="wiki[format]"
          :disabled="isContentEditorActive"
        >
          <option v-for="(key, label) of formatOptions" :key="key" :value="key">
            {{ label }}
          </option>
        </select>
      </div>
    </div>
    <div class="form-group row" data-testid="wiki-form-content-fieldset">
      <div class="col-sm-2 col-form-label">
        <label class="control-label-full-width" for="wiki_content">{{
          $options.i18n.content.label
        }}</label>
      </div>
      <div class="col-sm-10">
        <div
          v-if="showSwitchEditingModeButton"
          class="gl-display-flex gl-justify-content-end gl-mb-3"
        >
          <gl-button
            data-testid="toggle-editing-mode-button"
            data-qa-selector="editing_mode_button"
            :data-qa-mode="toggleEditingModeButtonText"
            variant="link"
            @click="toggleEditingMode"
            >{{ toggleEditingModeButtonText }}</gl-button
          >
        </div>
        <gl-alert
          v-if="showContentEditorAlert"
          class="gl-mb-6"
          variant="info"
          data-qa-selector="try_new_editor_container"
          :primary-button-text="$options.i18n.contentEditor.useNewEditor.primaryLabel"
          :secondary-button-text="$options.i18n.contentEditor.useNewEditor.secondaryLabel"
          :dismiss-label="$options.i18n.contentEditor.useNewEditor.secondaryLabel"
          :title="$options.i18n.contentEditor.useNewEditor.title"
          @primaryAction="initContentEditor"
          @secondaryAction="dismissContentEditorAlert"
          @dismiss="dismissContentEditorAlert"
        >
          <gl-sprintf :message="$options.i18n.contentEditor.useNewEditor.text">
            <template
              #link="// eslint-disable-next-line vue/no-template-shadow
                { content }"
              ><gl-link
                :href="contentEditorHelpPath"
                target="_blank"
                data-testid="content-editor-help-link"
                >{{ content }}</gl-link
              ></template
            >
          </gl-sprintf>
        </gl-alert>
        <gl-modal
          ref="confirmSwitchToOldEditorModal"
          modal-id="confirm-switch-to-old-editor"
          :title="$options.i18n.contentEditor.switchToOldEditor.modal.title"
          :action-primary="{ text: $options.i18n.contentEditor.switchToOldEditor.modal.primary }"
          :action-cancel="{ text: $options.i18n.contentEditor.switchToOldEditor.modal.cancel }"
          @primary="switchToOldEditor"
        >
          {{ $options.i18n.contentEditor.switchToOldEditor.modal.text }}
        </gl-modal>
        <markdown-field
          v-if="!isContentEditorActive"
          :markdown-preview-path="pageInfo.markdownPreviewPath"
          :can-attach-file="true"
          :enable-autocomplete="true"
          :textarea-value="content"
          :markdown-docs-path="pageInfo.markdownHelpPath"
          :uploads-path="pageInfo.uploadsPath"
          class="bordered-box"
        >
          <template #textarea>
            <textarea
              id="wiki_content"
              ref="textarea"
              v-model="content"
              name="wiki[content]"
              class="note-textarea js-gfm-input js-autosize markdown-area"
              dir="auto"
              data-supports-quick-actions="false"
              data-qa-selector="wiki_content_textarea"
              :autofocus="pageInfo.persisted"
              :aria-label="$options.i18n.content.label"
              :placeholder="$options.i18n.content.placeholder"
              @input="handleContentChange"
            >
            </textarea>
          </template>
        </markdown-field>

        <div v-if="isContentEditorActive">
          <gl-alert class="gl-mb-6" variant="tip" :dismissible="false">
            <gl-sprintf :message="$options.i18n.contentEditor.feedbackTip">
              <template
                #link="// eslint-disable-next-line vue/no-template-shadow
                { content }"
                ><gl-link
                  :href="$options.contentEditorFeedbackIssue"
                  target="_blank"
                  data-testid="wiki-markdown-help-link"
                  >{{ content }}</gl-link
                ></template
              >
            </gl-sprintf>
          </gl-alert>
          <content-editor
            :render-markdown="renderMarkdown"
            :uploads-path="pageInfo.uploadsPath"
            @initialized="loadInitialContent"
            @change="handleContentEditorChange"
          />
          <input id="wiki_content" v-model.trim="content" type="hidden" name="wiki[content]" />
        </div>

        <div class="clearfix"></div>
        <div class="error-alert"></div>

        <div class="form-text gl-text-gray-600">
          <gl-sprintf v-if="displayWikiSpecificMarkdownHelp" :message="$options.i18n.linksHelpText">
            <template #linkExample
              ><code>{{ linkExample }}</code></template
            >
            <template
              #link="// eslint-disable-next-line vue/no-template-shadow
                { content }"
              ><gl-link
                :href="wikiSpecificMarkdownHelpPath"
                target="_blank"
                data-testid="wiki-markdown-help-link"
                >{{ content }}</gl-link
              ></template
            >
          </gl-sprintf>
          <span v-if="displaySwitchBackToClassicEditorMessage">
            {{ $options.i18n.contentEditor.switchToOldEditor.helpText }}
            <gl-button variant="link" @click="confirmSwitchToOldEditor">{{
              $options.i18n.contentEditor.switchToOldEditor.label
            }}</gl-button>
          </span>
        </div>
      </div>
    </div>
    <div class="form-group row">
      <div class="col-sm-2 col-form-label">
        <label class="control-label-full-width" for="wiki_message">{{
          $options.i18n.commitMessage.label
        }}</label>
      </div>
      <div class="col-sm-10">
        <input
          id="wiki_message"
          v-model.trim="commitMessage"
          name="wiki[message]"
          type="text"
          class="form-control"
          data-qa-selector="wiki_message_textbox"
          :placeholder="$options.i18n.commitMessage.label"
        />
      </div>
    </div>
    <div class="form-actions">
      <gl-button
        category="primary"
        variant="confirm"
        type="submit"
        data-qa-selector="wiki_submit_button"
        data-testid="wiki-submit-button"
        :disabled="disableSubmitButton"
        >{{ submitButtonText }}</gl-button
      >
      <gl-button :href="cancelFormPath" class="float-right">{{ $options.i18n.cancel }}</gl-button>
    </div>
  </gl-form>
</template>
