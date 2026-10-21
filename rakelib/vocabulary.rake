# frozen_string_literal: true

namespace :vocabulary do
  desc "Generate docs/operators.adoc from the operator vocabulary"
  task :doc do
    require_relative "../script/operator_inventory"
    OperatorInventory.write
    puts "Wrote #{OperatorInventory::DOC}"
  end
end
