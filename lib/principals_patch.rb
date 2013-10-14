#encoding: utf-8

module Plugin
  module CustomFilterIssuePatch
    def self.included base
      base.class_eval do
        scope :member_of_all, lambda {|projects|
          projects = [projects] unless projects.is_a?(Array)
          if projects.empty?
            where("1=0")
          else
            ids = projects.map(&:id)
            uniq.joins(:members).where("#{Member.table_name}.project_id IN (?)", ids)
          end
        }
      end
    end
  end
end