# Plugin data for the end-to-end scenarios, run by start_server.sh after the
# generic seed (.codex/e2e/seed.rb). Idempotent.
#
#   viewer    member of e2e-project with a role that may only view to-do lists
#   lists     "E2E sprint" (two issues and a text item) and "E2E cleanup"
#             (removes closed issues) in e2e-project, "E2E private list" in
#             e2e-private
user_password = ENV.fetch('RMP_USER_PASSWORD', ENV.fetch('RMP_ADMIN_PASSWORD', 'Redmine7Test!'))
admin = User.find_by!(login: 'admin')
User.current = admin
project = Project.find_by!(identifier: 'e2e-project')
private_project = Project.find_by!(identifier: 'e2e-private')

viewer = User.find_by(login: 'viewer') ||
         User.new(login: 'viewer', firstname: 'Viewer', lastname: 'E2E', mail: 'viewer@example.net')
viewer.password = viewer.password_confirmation = user_password
viewer.must_change_passwd = false
viewer.status = User::STATUS_ACTIVE
viewer.save!(validate: false)

role = Role.find_by(name: 'E2E todo viewer') || Role.new(name: 'E2E todo viewer', assignable: true)
role.permissions = [:view_issues, :view_issue_todo_lists]
role.issues_visibility = 'all'
role.save!
Member.create!(principal: viewer, project: project, roles: [role]) unless Member.where(user_id: viewer.id, project_id: project.id).exists?

def e2e_list(project, title, attrs = {})
  IssueTodoList.find_by(project_id: project.id, title: title) ||
    IssueTodoList.create!({project: project, title: title, created_by: User.current}.merge(attrs))
end

sprint = e2e_list(project, 'E2E sprint', description: 'Sprint list with *two* issues and a text item.')
if sprint.issue_todo_list_items.none?
  [Issue.find_by!(project_id: project.id, subject: 'E2E assigned issue'),
   Issue.find_by!(project_id: project.id, subject: 'E2E unassigned issue')].each do |issue|
    IssueTodoListItem.create!(issue_todo_list: sprint, issue: issue, position: sprint.get_max_position)
  end
  IssueTodoListItem.create!(issue_todo_list: sprint, comment: 'Text item: order the coffee', position: sprint.get_max_position)
end
e2e_list(project, 'E2E cleanup', remove_closed_issues: true)
private_list = e2e_list(private_project, 'E2E private list')
if private_list.issue_todo_list_items.none?
  IssueTodoListItem.create!(issue_todo_list: private_list, issue: Issue.find_by!(project_id: private_project.id),
                            position: 1)
end

puts "Plugin seed: #{IssueTodoList.count} lists, #{IssueTodoListItem.count} items, user viewer"
