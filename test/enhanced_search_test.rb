require 'test/unit'
require File.join(File.dirname(__FILE__), 'test_helper')

class EnhancedSearchTest < Test::Unit::TestCase
  def setup
    Fixtures.create_fixtures(FIXTURES_DIRECTORY, :people)
  end

  def test_search_no_args_successful
    assert_not_nil(Person.search)
    assert_equal(Person.count, Person.search.size)
  end

  def test_search_match_partial
    Person.search(:columns => { 'name' => '郎' }).each do |person|
      assert_match(/郎/, person.name)
    end
  end

  def test_search_match_full
    Person.search(:columns => { 'sex' => 'male' }).each do |person|
      assert_equal('male', person.sex)
    end
    Person.search(:columns => { 'sex' => 'female' }).each do |person|
      assert_equal('female', person.sex)
    end
  end

  def test_search_opened_scope
    Person.search(:columns => { 'age_from' => 22, 'age_to' => nil }).each do |person|
      assert(person.age >= 22)
    end
    Person.search(:columns => { 'age_from' => nil, 'age_to' => 20 }).each do |person|
      assert(person.age <= 20)
    end
    Person.search(:columns => { 'age_from' => 22, 'age_to' => 26 }).each do |person|
      assert(person.age >= 22)
      assert(26 >= person.age)
    end
  end

  def test_search_closed_scope
    columns = { 'number_from' => '123456789', 'number_to' => nil }
    Person.search(:columns => columns).each do |person|
      assert_equal(123456789, person.number)
    end
    assert_equal(1, Person.search(:columns => columns).size)

    columns = { 'number_from' => '123456789', 'number_to' => '123456790' }
    Person.search(:columns => columns).each do |person|
      assert(123456789 <= person.number)
      assert(123456790 >= person.number)
    end
  end

  def test_search_including
    columns = { 'area' => %w(1 2 3) }
    Person.search(:columns => columns).each do |person|
      assert([1, 2, 3].include?(person.area))
    end
  end

  def test_aliases_column
    Person.search(:columns => { 'western_male' => 'true' }).each do |person|
      assert_equal(Person::AREAS[:west], person.area)
      assert_equal('male', person.sex)
    end
  end

  def test_additional_conditions
    Person.search(:additional_conditions => ['sex = ?', 'male']).each do |person|
      assert_equal('male', person.sex)
    end
  end

  def test_additional_conditions_with_columns
    Person.search(:columns => { 'area' => %w(1 2 3 4) },
                  :additional_conditions => ['sex = ?', 'male']).each do |person|
      assert_equal('male', person.sex)
    end
  end

  def test_search_column_names
    assert_not_nil(Person.search_column_names)
    search_column_names = 
      %w(name sex age_from age_to number_from number_to area western_male)
    Person.search_column_names.each do |name|
      assert(search_column_names.include?(name))
    end
  end
end
