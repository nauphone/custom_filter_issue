require_dependency 'query'

module IssuesCategoryPlugin
  module QueryPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        alias_method_chain :initialize_available_filters, :category
      end

    end

    module InstanceMethods
      def initialize_available_filters_with_category
        principals = []
        subprojects = []
        versions = []
        categories = []
        issue_custom_fields = []
        if project
          principals += project.principals.sort
          unless project.leaf?
            subprojects = project.descendants.visible.all
            principals += Principal.member_of(subprojects)
          end
          versions = project.shared_versions.all

          categories = []
          project.hierarchy.each do |cats|
            categories += cats.issue_categories
          end

          issue_custom_fields = project.all_issue_custom_fields
        else
          if all_projects.any?
            principals += Principal.member_of(all_projects)
          end
          versions = Version.visible.find_all_by_sharing('system')
          issue_custom_fields = IssueCustomField.where(:is_filter => true, :is_for_all => true).all
          categories = IssueCategory.all
        end
        principals.uniq!
        principals.sort!
        users = principals.select {|p| p.is_a?(User)}


        add_available_filter "status_id",
          :type => :list_status, :values => IssueStatus.sorted.all.collect{|s| [s.name, s.id.to_s] }

        if project.nil?
          project_values = []
          if User.current.logged? && User.current.memberships.any?
            project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
          end
          project_values += all_projects_values
          add_available_filter("project_id",
            :type => :list, :values => project_values
          ) unless project_values.empty?
        end

        add_available_filter "tracker_id",
          :type => :list, :values => trackers.collect{|s| [s.name, s.id.to_s] }
        add_available_filter "priority_id",
          :type => :list, :values => IssuePriority.all.collect{|s| [s.name, s.id.to_s] }

        author_values = []
        author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
        author_values += users.collect{|s| [s.name, s.id.to_s] }
        add_available_filter("author_id",
          :type => :list, :values => author_values
        ) unless author_values.empty?

        assigned_to_values = []
        assigned_to_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
        assigned_to_values += (Setting.issue_group_assignment? ?
                                  principals : users).collect{|s| [s.name, s.id.to_s] }
        add_available_filter("assigned_to_id",
          :type => :list_optional, :values => assigned_to_values
        ) unless assigned_to_values.empty?

        group_values = Group.all.collect {|g| [g.name, g.id.to_s] }
        add_available_filter("member_of_group",
          :type => :list_optional, :values => group_values
        ) unless group_values.empty?

        role_values = Role.givable.collect {|r| [r.name, r.id.to_s] }
        add_available_filter("assigned_to_role",
          :type => :list_optional, :values => role_values
        ) unless role_values.empty?

        if versions.any?
          add_available_filter "fixed_version_id",
            :type => :list_optional,
            :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
        end

        if categories.any?
          add_available_filter "category_id",
            :type => :list_optional,
            :values => categories.collect{|s| [s.name + ' - '  + Project.find(s.project_id).name, s.id.to_s] }.sort
        end

        add_available_filter "subject", :type => :text
        add_available_filter "created_on", :type => :date_past
        add_available_filter "updated_on", :type => :date_past
        add_available_filter "closed_on", :type => :date_past
        add_available_filter "start_date", :type => :date
        add_available_filter "due_date", :type => :date
        add_available_filter "estimated_hours", :type => :float
        add_available_filter "done_ratio", :type => :integer

        if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
          User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
          add_available_filter "is_private",
            :type => :list,
            :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
        end

        if User.current.logged?
          add_available_filter "watcher_id",
            :type => :list, :values => [["<< #{l(:label_me)} >>", "me"]]
        end

        if subprojects.any?
          add_available_filter "subproject_id",
            :type => :list_subprojects,
            :values => subprojects.collect{|s| [s.name, s.id.to_s] }
        end

        add_custom_fields_filters(issue_custom_fields)

        add_associations_custom_fields_filters :project, :author, :assigned_to, :fixed_version

        IssueRelation::TYPES.each do |relation_type, options|
          add_available_filter relation_type, :type => :relation, :label => options[:name]
        end

        Tracker.disabled_core_fields(trackers).each {|field|
          delete_available_filter field
        }
      end
    end
  end
end

IssueQuery.send(:include, IssuesCategoryPlugin::QueryPatch) unless IssueQuery.included_modules.include? IssuesCategoryPlugin::QueryPatch
