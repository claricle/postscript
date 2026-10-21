# frozen_string_literal: true

require_relative "../lib/postscript"

# Generates the operator inventory from the vocabulary and class registry.
module OperatorInventory
  DOC = File.expand_path("../docs/operators.adoc", __dir__)
  INTRO = "This page is generated; do not edit. Regenerate with " \
          "`bundle exec rake vocabulary:doc`. It is built from " \
          "`data/guide_operators.yml` (PostScript Language Guide) and " \
          "`data/operator_overrides.yml`, and lists each operator with " \
          "the gem class that models it or `UnknownOperator` when no class " \
          "is registered (the parser then yields " \
          "`Postscript::Model::UnknownOperator`)."
  TABLE_HEADER = <<~ADOC
    [cols="2,3,1,1,5",options="header"]
    |===
    |Operator |Categories |Level |Source |Gem class
  ADOC

  class << self
    def render
      Postscript::Model::Operators.load_all!
      rows = keywords.map { |keyword| row(keyword) }.join("\n")
      [
        "= PostScript operator inventory", "", INTRO, "", TABLE_HEADER,
        rows, "|===", "", totals_line, ""
      ].join("\n")
    end

    def totals_line
      modeled = modeled_count
      "#{keywords.size} operators; #{modeled} with a gem class; " \
        "#{keywords.size - modeled} represented as UnknownOperator. " \
        "By level: #{level_counts.join(', ')}."
    end

    def write(path = DOC)
      File.write(path, render)
    end

    private

    def keywords
      Postscript::Model::Vocabulary.keywords
    end

    def row(keyword)
      entry = Postscript::Model::Vocabulary.entry(keyword)
      cells = [
        "`+#{keyword.gsub('|') { '\\|' }}+`", categories(entry),
        entry.level || "-", entry.source.to_s, gem_class(keyword)
      ]
      "|#{cells.join(' |')}"
    end

    def categories(entry)
      entry.categories.empty? ? "-" : entry.categories.join(", ")
    end

    def gem_class(keyword)
      klass = Postscript::Model::Operators[keyword]
      "`#{klass ? klass.name : 'UnknownOperator'}`"
    end

    def modeled_count
      keywords.count { |keyword| Postscript::Model::Operators[keyword] }
    end

    def level_counts
      counts = keywords.map do |keyword|
        Postscript::Model::Vocabulary.entry(keyword).level
      end.tally
      levels = counts.keys.compact.sort.map do |level|
        "level #{level}: #{counts.fetch(level)}"
      end
      levels << "unknown: #{counts.fetch(nil)}" if counts.key?(nil)
      levels
    end
  end
end
