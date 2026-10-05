# CHANGELOG
### 2.4.0
* Support Redmine 7.0, require Redmine 5.1 or later
* Security: check permissions, project and issue visibility on every to-do list action
* Hide to-do lists of projects without the module, also for administrators
* Fix the CSV export (UTF-8), the to-do list filter and the API for lists with text items
* Fix sorting the issue list on the to-do list columns
* Fix deleting a user who created or edited a to-do list
* Fix lost to-do list items when an issue form opened earlier is saved
* Show icons and translations correctly on Redmine 6 and 7
* Run the migration, it adds indexes

### 2.3.0
* Remove the `Dates` context menu. It moved to [redmine_context_menu_actions](https://github.com/jcatrysse/redmine_context_menu_actions).  
  Install that plugin together with this upgrade if you use the Dates menu.
* Add a test suite, run it with the `.codex` scripts
* The plugin now ships a `Gemfile` (test gems only): run `bundle install` after updating

### 2.2.2
* Add options to toggle issue sidebar and edit-form to-do lists
* Apply query optimizations and localization updates
* Resolve issues with legacy todo lists and migration
* Resolve issue with missing columns in the todolists

### 2.2.1
* Add YAML coder to serializer, for Rails 7 / Redmine 6 compatibility (thank you bytemine Team)
* Add a configurable `Date` context menu to change start and end dates on issues
* Correct a stylesheet issue (autoscroll - overflow-x: auto;)

### 2.2.0
* Restore the previous functionality to add text only todo items (thank you Anass Dkhissi)

### 2.1.9
* Resolve issue: `Mysql2::Error: Column 'position' in order clause is ambiguous`

### 2.1.8
* Resolve issue in Redmine 4 not supporting Rails.autoloaders

### 2.1.7
* Resolved issue: `SystemStackError (stack level too deep)`  
  Converted methods to use `alias_method`

### 2.1.6
* Correction for `admin` privileges: *admin should always have full access*
* Correction for `Filters` and `Columns` not showing all available `to-do lists`
* Only show `to-do lists` where the user has sufficient privileges
* Only show `Column` values where the user has sufficient privileges
* Add a link to the `to-do lists titles` Column

### 2.1.5
*  complete rework of db migration scripts, to avoid errors on migrations, better SQL compliancy and optimizations on large datasets
*  add foreign key constraints and some fields have been renamed for cosmetic reasons
*  corrections in the `visible?` method

### 2.1.4
* further corrections on Zeitwork not ignoring Liquid when missing
* refactor migration scripts, to be fully compatible (using Active Record)
* correct references to the former plugin's assets

### 2.1.3
* correction of a deprecated Rails method in Redmine 5

### 2.1.2
* resolve error when liquid is missing

### 2.1.1
* correction not removing items from todolist when closed

### 2.1.0
* NL and FR translations
* update DE, ES and ZH translations (not verified)
* add to-do list selection on issue `edit` or `creation`
* corrections on some structural issues

### 2.0.0
* mainly a move to a new maintained repository (thank you Den / Canidas for your work)
* complete rework of the underlying file structure
* add todolist on issue creation

### 1.4.0
* make compatible with Redmine 5
* add full context menu
* add sortable columns in picker
* add CSV export
* add sidebar in issue details
* add filter
* correct flicker in gui
* add support for liquid
* add method `issue.todolists_with_positions.items`

Changes by: Jan Catrysse

### 1.3.2
* allow configuration of issue columns per todo list
* added functionality to include issue columns for text items
* wiki toolbar for new items
* show text item field editor as date in case column name contains `date` word
* refactoring of item editing functionality
* added ginstr credits
* DB MIGRATION IS REQUIRED FOR THIS VERSION (to 7) 

### 1.3.1
* first extended version
* changes to init.rb
* added wiki toolbar to todo list description
* modifications of sortable behavior
* remove autoscroll for table wrapper
* added "Add" button for items (just in case)
* added possibility to edit item comment with wiki toolbar
* added textile support for comments
* added "Order" column to table
* new permission "update items"

