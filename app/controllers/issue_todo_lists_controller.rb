class IssueTodoListsController < ApplicationController

  before_action :find_project
  before_action :find_todo_list, :only => [:show, :edit, :update, :destroy, :update_item_order, :bulk_allocate_issues]
  before_action :authorize_view, :only => [:update_item_order]

  accept_api_auth :index, :show

  include IssueTodoListsHelper
  def index
    @todo_lists = @project.issue_todo_lists.order('id')
    respond_to do |format|
      format.api
      format.html { render action: 'index', layout: false if request.xhr? }
    end
  end

  def new
    @todo_list = IssueTodoList.new
    @issue_query = IssueQuery.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @todo_list = IssueTodoList.new(issue_todo_list_params)
    @todo_list.project_id = @project.id
    @todo_list.created_by = User.current
    if @todo_list.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:issue_todo_lists_new_success)
          redirect_to project_issue_todo_list_path(@project, @todo_list)
        }
      end
    else
      @issue_query = IssueQuery.new
      respond_to do |format|
        format.html { render 'form' }
      end
    end
  end

  def show
    @todo_list_items = @todo_list.visible_items_for_display
    @issue_query = IssueQuery.new
    respond_to do |format|
      format.api
      format.html { render action: 'show', layout: false if request.xhr? }
      format.csv  { send_data(todo_list_items_to_csv(@todo_list, @todo_list_items, @issue_query), :type => 'text/csv; header=present', :filename => 'issue_todo_list_items.csv') }
    end
  end

  def edit
    @issue_query = IssueQuery.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def update
    respond_to do |format|
      if @todo_list.update(issue_todo_list_params)
        format.html { redirect_to project_issue_todo_list_path(@project, @todo_list), notice: l(:issue_todo_lists_edit_success) }
      else
        @issue_query = IssueQuery.new
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @todo_list.destroy

    respond_to do |format|
      format.html { redirect_to project_issue_todo_lists_path(@project), notice: l(:issue_todo_lists_destroy_success) }
    end
  end

  # Items the user cannot see keep their place; the others take the
  # positions in the order they were posted.
  def update_item_order
    ids = Array(params[:item]).map { |id| id.to_s.to_i }
    items = @todo_list.visible_items.where(id: ids).index_by(&:id)
    ordered = ids.map { |id| items[id] }.compact.uniq

    positions =
      if ordered.size == @todo_list.issue_todo_list_items.count
        (1..ordered.size).to_a
      else
        ordered.map { |item| item.position.to_i }.sort
      end
    IssueTodoListItem.transaction do
      ordered.each_with_index do |item, index|
        item.update_column(:position, positions[index]) unless item.position == positions[index]
      end
      @todo_list.mark_updated
    end
    @todo_list_items = @todo_list.visible_items_for_display
    @issue_query = IssueQuery.new

    respond_to(&:js)
  end

  # Used by the issue context menu and the issue sidebar.
  def bulk_allocate_issues
    ids = Array(params[:issue_ids]).map { |id| id.to_s.to_i }
    # In the posted order, which becomes the order in the list.
    issues = Issue.visible.where(:id => ids).sort_by { |issue| ids.index(issue.id) }
    return render_404 if issues.empty?

    listed_ids = @todo_list.issue_todo_list_items.where(:issue_id => issues.map(&:id)).pluck(:issue_id)
    # A negative count is an unlist, as chosen in the menu, even when the
    # list changed after the menu was opened.
    if params[:list_count].to_i.negative?
      return deny_access unless User.current.allowed_to?(:add_issue_todo_list_items_context_menu, @project) ||
                                User.current.allowed_to?(:remove_issue_todo_list_items, @project)

      @todo_list.issue_todo_list_items.where(:issue_id => listed_ids).destroy_all
    else
      errors = issues.reject { |issue| listed_ids.include?(issue.id) }.flat_map do |issue|
        # Not saved when the list removes closed issues and this one is closed.
        IssueTodoListItem.create(:issue_todo_list => @todo_list, :issue => issue, :position => @todo_list.get_max_position)
                         .errors.full_messages
      end
      flash[:error] = errors.uniq.to_sentence if errors.any?
    end

    redirect_back_or_default project_issue_todo_list_path(@project, @todo_list)
  end

  private
  def find_project
    @project = Project.find(params[:project_id])
    authorize
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # The response shows the list, so the view permission is needed as well.
  def authorize_view
    deny_access unless User.current.allowed_to?(:view_issue_todo_lists, @project)
  end

  def find_todo_list
    @todo_list = @project.issue_todo_lists.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def issue_todo_list_params
    list_params = params.require(:issue_todo_list)
    raise ActionController::ParameterMissing, :issue_todo_list unless list_params.is_a?(ActionController::Parameters)

    list_params[:included_columns] ||= []
    list_params[:included_fields] ||= []
    list_params.permit(:title, :description, :remove_closed_issues, :included_columns => [], :included_fields => [])
  end
end
