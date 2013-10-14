#encoding: utf-8


ActionDispatch::Callbacks.to_prepare  do
  require 'principals_patch'
  require 'category_search_path'
  Principal.send(:include, ::Plugin::CustomFilterIssuePatch)
end

Redmine::Plugin.register :custom_filter_issue do
  name 'Custom filter issue Plugin'
  author 'Alexei Margasov'
  version '0.0.1'
end
