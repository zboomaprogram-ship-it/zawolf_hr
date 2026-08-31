'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  canStartConversation,
  canAccessDepartment,
  departmentKey,
  containsExternalDriveLink,
  isConversationMember,
  normalizeMemberIds,
  normalizeMessageInput,
} = require('../conversation-operations');
const {
  uploadGovernedAttachment,
  downloadGovernedAttachment,
} = require('../workspace/drive-operations');

test('membership normalization always includes the caller and rejects broad rooms', () => {
  assert.deepEqual(
    normalizeMemberIds('employee-1', ['manager-1', 'employee-1', 'manager-1']),
    ['employee-1', 'manager-1'],
  );
  assert.equal(
    normalizeMemberIds('employee-1', Array.from({ length: 11 }, (_, i) => `u-${i}`)),
    null,
  );
});

test('employees can start only with their own manager, HR, or admin', () => {
  const actor = { uid: 'employee-1', role: 'employee' };
  const actorUser = { managerIds: ['manager-1'] };
  assert.equal(canStartConversation({
    actor,
    actorUser,
    memberUsers: [
      { uid: 'employee-1', role: 'employee', isActive: true },
      { uid: 'manager-1', role: 'manager', isActive: true },
    ],
  }), true);
  assert.equal(canStartConversation({
    actor,
    actorUser,
    memberUsers: [
      { uid: 'employee-1', role: 'employee', isActive: true },
      { uid: 'employee-2', role: 'employee', isActive: true },
    ],
  }), false);
});

test('messages reject raw Drive links and keep opaque attachment references', () => {
  assert.equal(containsExternalDriveLink('https://drive.google.com/file/d/secret'), true);
  assert.equal(normalizeMessageInput({
    operationId: 'message-1',
    body: 'الرابط https://docs.google.com/spreadsheets/d/secret',
  }), null);
  assert.deepEqual(normalizeMessageInput({
    operationId: 'message-1',
    body: 'تم إرفاق الملف',
    attachmentResourceIds: ['attachment-1'],
  }), {
    operationId: 'message-1',
    body: 'تم إرفاق الملف',
    attachmentResourceIds: ['attachment-1'],
  });
});

test('closed conversations and non-members cannot send', () => {
  assert.equal(isConversationMember({
    state: 'active', memberUserIds: ['employee-1', 'manager-1'],
  }, 'employee-2'), false);
  assert.equal(isConversationMember({
    state: 'closed', memberUserIds: ['employee-1', 'manager-1'],
  }, 'employee-1'), false);
});

test('department channels stay inside the department while HR and admins cross departments', () => {
  assert.equal(canAccessDepartment({
    uid: 'employee-1', role: 'employee', department: 'المبيعات',
  }, 'المبيعات'), true);
  assert.equal(canAccessDepartment({
    uid: 'employee-1', role: 'employee', department: 'المبيعات',
  }, 'الحسابات'), false);
  assert.equal(canAccessDepartment({
    uid: 'hr-1', role: 'hr_admin', department: 'الموارد البشرية',
  }, 'الحسابات'), true);
  assert.equal(canAccessDepartment({
    uid: 'admin-1', role: 'admin', department: '',
  }, 'المبيعات'), true);
  assert.equal(departmentKey('  قسم   المبيعات  '), 'قسم المبيعات');
});

test('governed attachments cross the Drive provider boundary without public links', async () => {
  const calls = [];
  const connector = {
    uploadWorkspaceDriveFile: async (payload) => {
      calls.push(['upload', payload]);
      return { id: 'provider-file-secret' };
    },
    downloadWorkspaceDriveFile: async (payload) => {
      calls.push(['download', payload]);
      return { bytes: Buffer.from('safe') };
    },
  };
  const uploaded = await uploadGovernedAttachment({
    connector,
    parentFolderId: 'governed-folder',
    payload: {
      name: 'evidence.pdf',
      mimeType: 'application/pdf',
      contentsBase64: 'c2FmZQ==',
    },
  });
  assert.deepEqual(uploaded, { id: 'provider-file-secret' });
  await downloadGovernedAttachment({
    connector,
    parentFolderId: 'governed-folder',
    externalFileId: 'provider-file-secret',
  });
  assert.equal(calls.length, 2);
  assert.equal(JSON.stringify(calls).includes('drive.google.com'), false);
});
