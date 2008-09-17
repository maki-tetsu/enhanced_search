require 'rubygems'
gem 'activerecord'
require 'active_record'
require 'active_record/fixtures'
require File.join(File.dirname(__FILE__), '../init')

FIXTURES_DIRECTORY = File.join(File.dirname(__FILE__), 'fixtures')

ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                        :database => ":memory:")

ActiveRecord::Schema.define(:version => 1) do
  create_table(:people) do |t|
    t.string(:name)
    t.string(:sex)
    t.integer(:age)
    t.integer(:number)
    t.integer(:area)
  end
end


class Person < ActiveRecord::Base
  AREAS = { :west => 1, :east => 2, :south => 3, :north => 4 }

  enhanced_search(:columns => {'name'         => :match_partial,
                               'sex'          => :match_full,
                               'age'          => :opened_scope,
                               'number'       => :closed_scope,
                               'area'         => :including,
                               'western_male' => :match_full },
                  :aliases => { 'western_male' => "area = 1 AND sex = 'male'" },
                  :order => ['id', 'ASC'])
end
