Redmine::Plugin.register :redmine_issue_todo_lists2 do
  name 'Issue To-do Lists Plugin (reworked)'
  author 'Jan Catrysse'
  description 'Organize issues in to-do lists by manually ordering their priority'
  version '2.1.7'
  url 'https://github.com/jcatrysse/redmine_issue_todo_lists2'
  author_url 'https://github.com/jcatrysse'

  requires_redmine version_or_higher: '4.0'

  project_module :issue_todo_lists do
    permission :add_issue_todo_lists, {:issue_todo_lists => [:new, :create]}
    permission :view_issue_todo_lists, {:issue_todo_lists => [:index, :show]}
    permission :edit_issue_todo_lists, {:issue_todo_lists => [:update, :edit]}
    permission :delete_issue_todo_lists, {:issue_todo_lists => [:destroy]}
    permission :add_issue_todo_list_items, {:issue_todo_list_items => [:create]}
    permission :order_issue_todo_list_items, {:issue_todo_lists => [:update_item_order]}
    permission :remove_issue_todo_list_items, {:issue_todo_list_items => [:destroy]}
    permission :update_issue_todo_list_items, {:issue_todo_list_items => [:update, :show, :edit]}
    permission :add_issue_todo_list_items_context_menu, {:issue_todo_lists => [:bulk_allocate_issues]}
  end

  menu :project_menu, :issue_todo_lists, { :controller => 'issue_todo_lists', :action => 'index' }, :caption => :issue_todo_lists_title, :param => :project_id, :after => :activity
end

require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/hooks/view_issues_details_bottom_hook'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/hooks/view_issues_context_menu_end_hook'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/hooks/view_issues_form_details_bottom_hook'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/hooks/controller_issues_new_after_save_hook'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/hooks/controller_issues_edit_after_save_hook'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/issue_patch'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/project_patch'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/issue_query_patch'
require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/query_helper_patch'

if defined?(::Liquid::Drop)
  require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/liquid/todo_lists_drop'
  require File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/issue_drop_patch.rb'
else
  liquid_files = [File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/liquid/todo_lists_drop.rb',
                  File.dirname(__FILE__) + '/lib/redmine_issue_todo_lists/patches/issue_drop_patch.rb']

  Rails.autoloaders.each do |autoloader|
    autoloader.ignore(liquid_files)
  end
end
