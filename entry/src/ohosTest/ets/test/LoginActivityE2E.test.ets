import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@kit.TestKit';

import {
  E2E_PERSONAL_TITLE,
  E2E_PROJECT_TITLE,
  E2E_TOKEN,
  E2E_TODO_ISSUE_TITLE,
  E2E_TODO_OWNED_ISSUE_TITLE,
  E2E_TODO_OWNED_PULL_TITLE,
  E2E_TODO_PULL_TITLE
} from '../testability/E2EFakes';

const UI_WAIT_MS: number = 10000;

export default function loginActivityE2E() {
  describe('LoginActivityE2E', () => {
    it('logs_in_and_opens_activity_and_todo_worklists', 0, async () => {
      const driver = Driver.create();
      const input = await driver.waitForComponent(ON.id('login_token_input'), UI_WAIT_MS);
      await input.inputText(E2E_TOKEN);
      await driver.pressBack();

      const submit = await driver.waitForComponent(ON.id('login_submit'), UI_WAIT_MS);
      await submit.click();

      await driver.waitForComponent(ON.id('activity_page'), UI_WAIT_MS);
      await driver.assertComponentExist(ON.text(E2E_PERSONAL_TITLE));

      const projects = await driver.waitForComponent(ON.id('topbar_segment_1'), UI_WAIT_MS);
      await projects.click();
      await driver.waitForComponent(ON.text(E2E_PROJECT_TITLE), UI_WAIT_MS);

      const openTodo = await driver.waitForComponent(ON.id('e2e_open_todo_root'), UI_WAIT_MS);
      await openTodo.click();
      await driver.waitForComponent(ON.id('todo_page'), UI_WAIT_MS);

      const issues = await driver.waitForComponent(ON.id('todo_open_issues'), UI_WAIT_MS);
      await issues.click();
      await driver.waitForComponent(ON.id('todo_worklist_page_issues'), UI_WAIT_MS);
      await driver.waitForComponent(ON.text(E2E_TODO_ISSUE_TITLE), UI_WAIT_MS);
      await driver.assertComponentExist(ON.text(E2E_TODO_OWNED_ISSUE_TITLE));

      await driver.pressBack();
      await driver.waitForComponent(ON.id('todo_page'), UI_WAIT_MS);

      const pulls = await driver.waitForComponent(ON.id('todo_open_pull_requests'), UI_WAIT_MS);
      await pulls.click();
      await driver.waitForComponent(ON.id('todo_worklist_page_pull_requests'), UI_WAIT_MS);
      await driver.waitForComponent(ON.text(E2E_TODO_PULL_TITLE), UI_WAIT_MS);
      await driver.assertComponentExist(ON.text(E2E_TODO_OWNED_PULL_TITLE));

      expect(true).assertTrue();
    });
  });
}
