class IssueTodoListItemsController < ApplicationController

  before_action :find_project
  before_action :authorize_view
  before_action :find_todo_list
  before_action :find_item, :only => [:edit, :update, :destroy]

  def create
    @item = IssueTodoListItem.new(:issue_todo_list => @todo_list, :position => @todo_list.get_max_position)
    @item.comment = item_params[:comment]

    issue_ref = item_params[:issue_id].to_s.strip
    if issue_ref.present?
      issue_id = issue_ref[/\A#?(\d+)\z/, 1]
      @item.issue = Issue.visible.find_by(:id => issue_id) if issue_id
      @item.errors.add(:base, l(:error_issue_not_found_in_project)) if @item.issue.nil?
    elsif @item.comment.blank?
      # A text item needs at least a comment.
      @item.errors.add(:base, l(:issue_todo_lists_item_create_empty))
    end
    # Keep the errors added above, save would clear them.
    @saved = @item.errors.empty? && @item.save

    respond_to do |format|
      format.js { load_items }
    end
  end

  def edit
    respond_to do |format|
      format.js {
        @issue_query = IssueQuery.new
        render :edit
      }
    end
  end

  def destroy
    @item.destroy

    respond_to do |format|
      format.html { redirect_back_or_default project_issue_todo_list_path(@project, @todo_list) }
      format.js {
        load_items
        render :update
      }
    end
  end

  def update
    @item.comment = item_params[:comment] if item_params.key?(:comment)
    data = params[:item][:data]
    if data.is_a?(Array)
      posted = data.select { |entry| entry.respond_to?(:key?) && @todo_list.included_fields.include?(entry[:field].to_s) }
                   .map { |entry| {field: entry[:field].to_s, value: entry[:value].to_s} }
      # Values of fields the list no longer shows are kept.
      kept = Array(@item.data).reject { |entry| posted.any? { |p| p[:field] == (entry[:field] || entry['field']).to_s } }
      @item.data = kept + posted
    end
    @item.save

    respond_to do |format|
      format.js { load_items }
    end
  end

  private
  def find_project
    @project = Project.find(params[:project_id])
    authorize
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # The responses show the list, so the view permission is needed as well.
  def authorize_view
    deny_access unless User.current.allowed_to?(:view_issue_todo_lists, @project)
  end

  def find_todo_list
    @todo_list = @project.issue_todo_lists.find(params[:issue_todo_list_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Only items the user can see.
  def find_item
    @item = @todo_list.visible_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def item_params
    item = params.require(:item)
    raise ActionController::ParameterMissing, :item unless item.is_a?(ActionController::Parameters)

    item
  end

  def load_items
    @todo_list.reload
    @todo_list_items = @todo_list.visible_items_for_display
    @issue_query = IssueQuery.new
  end
end
