module MakiTetsu #:nodoc:
  module Enhanced #:nodoc:
    # = AR に一般的な検索機能を提供する Mix-in 用モジュール
    #
    # 一般的に AR オブジェクトは一覧・検索機能を必要とする。マスタ系の場合は
    # 必須と言えます。MakiTetsu::Enhanced::Search は簡単な設定で動的な Sercher を
    # 提供します。具体的には、AR を継承したクラス内で enhanced_search クラス
    # メソッドを呼び出すことで search メソッドを生成します。search メソッドの
    # 動作については enhanced_search のオプションによって決定されます。
    #
    # == 具体的な使用方法
    #
    # name, sex, age を属性として持つ Person モデルがあるとします。この Person
    # モデルに対し、以下の検索条件を持つ search メソッドを定義するとします。
    #
    # * name に対する部分一致検索
    # * sex に対する完全一致検索
    # * age に対する開放範囲検索
    #
    # 以下のように enhanced_search メソッドを呼び出します。
    #   class Person < ActiveRecord::Base
    #     enhanced_search(:columns => {'name' => :match_partial,
    #                                  'sex'  => :match_full,
    #                                  'age'  => :opened_scope})
    #   end
    # 上記のように定義することで以下のような呼び出しが可能となります。
    #
    # name に太郎が含まれる人を検索
    #   Person.search(:columns => {'name' => '太郎'})
    # name に太郎が含まれ、かつ、age が 25 以下の人を検索
    #   Person.search(:columns => {'name' => '太郎', 'age_from' => nil, 'age_to' => 25})
    #
    # == 検索設定方法
    #
    # 検索方法の設定は enhanced_search メソッドの呼び出しで設定を行います。
    # 設定方法は個々の設定をハッシュとして渡します。
    # 設定できる項目は以下の項目になります。
    #
    # <tt>:columns</tt>::
    #   検索カラムの指定と検索手法の指定(省略不可)
    # <tt>:order</tt>::
    #   デフォルトの並び順指定
    # <tt>:include</tt>::
    #   Eager Loading 設定
    # <tt>:aliases</tt>::
    #   検索カラムの別名定義リスト
    # <tt>:finder</tt>::
    #   内部で呼び出す finder の指定（デフォルト: :find）
    #
    # === 検索カラムの指定と検索手法の指定
    #
    # 検索カラムの指定と検索手法の指定は省略不可能な引数である <tt>columns</tt>
    # で行います。<tt>columns</tt> はハッシュとして渡します。キーはカラム名、
    # もしくは、後述の別名定義を文字列で渡し、値に検索手法を渡します。
    # 検索手法の指定はシンボルで行います。
    # 
    # 検索手法は大きく分けて一致検索と範囲検索および、
    # 包含検索 から構成されます。検索方法によって search メソッド
    # 呼び出し時に引き渡す値が異なります。
    #
    # 一致検索::
    #   マッチングに利用する値を単一の値で渡す
    # 範囲検索::
    #   範囲を指定するために 2 つの要素から成る配列を渡す
    # 包含検索::
    #   対象レコードが含んでいることを期待する値の集合を配列で渡す
    #
    # <tt>:match_full</tt>::
    #   完全一致検索を指定します。
    #   conditions では = を用いて表現されます。
    # <tt>:match_partial</tt>::
    #   部分一致検索を指定します。指定された値の前後に % を付与し、
    #   LIKE を用いて conditions に追加します。
    # <tt>:closed_scope</tt>::
    #   閉塞範囲検索を指定します。上限値、もしくは、下限値のみが指定された
    #   場合は、両方に同じ値を適用して検索を行います。conditions では
    #   対象カラムに対し <= を用いて範囲で挟みます。
    # <tt>:opened_scope</tt>::
    #   開放範囲検索を指定します。上限値、もしくは、下限値のみが指定された
    #   場合は、有効な値のみで検索を行います。
    # <tt>:including</tt>::
    #   包含検索を指定します。値セットを元に対象カラムが含まれるかどうかで
    #   検索を行います。conditions では IN を用いて検索を行います。
    #
    # === デフォルトの並び替え順指定
    #
    # <tt>:order</tt> に <tt>ActiveRecord::Base#find</tt> メソッドに指定する
    # 形式でソート順を指定します。内容は配列で指定し、実際に <tt>find</tt> が
    # 呼ばれる段階で <tt>Array#join</tt> して <tt>find</tt> の <tt>order</tt>
    # パラメータに渡されます。
    #
    # === Eager Loading 設定
    #
    # <tt>ActiveRecord::Base#find</tt> にある <tt>:include</tt> をオプションと
    # 同様のオプション。<tt>find</tt> 呼び出し時に一緒に渡される。
    #
    # === 検索カラムの別名定義リスト
    #
    # 複数のカラムを組み合わせた結果や、複雑な条件判定などをあらかじめ別名定義
    # し、<tt>:columns</tt> オプションに指定可能とする別名のリストを渡します。
    # リレーション先を指定する場合などに利用します。
    #
    # 以下の例では姓と名からなるカラムに対して、連結したものを検索対象とします。
    #   # Schema Information
    #   # first_name:    string(30)
    #   # family_name:   string(30)
    #   class Person < ActiveRecord::Base
    #     enhanced_search(:columns => {'name' => :match_partial},
    #                     :aliases => {'name' => "CONCAT(first_name, ' ', family_name)"})
    #   end
    #
    module Search
      def self.included(base) #:nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        # 検索対象カラムの検索手法指定シンボル
        VALID_SEARCH_TYPES = [:match_full, :match_partial,
                              :closed_scope, :opened_scope, :including]

        # === 概要
        #
        # enhaced_search の設定項目を伴い有効化設定を行います。
        #
        # === 使用例
        #   enhanced_search(:columns  => {'name'     => :match_partial,
        #                                 'age'      => :opened_scope,
        #                                 'sex'      => :match_full,
        #                                 'favarite' => :including},
        #                   :include  => [:favarites],
        #                   :aliasaes => {'favarite' => 'favarites.id'},
        #                   :order    => ['name', 'ASC'])
        #
        # === 引数
        #
        # <tt>options</tt>::
        #   search メソッドの設定を指定します。
        #   <tt>:columns</tt>::
        #     検索カラムの指定と検索手法の指定(省略不可)
        #   <tt>:order</tt>::
        #     デフォルトの並び順指定
        #   <tt>:include</tt>::
        #     Eager Loading 設定
        #   <tt>:aliases</tt>::
        #     検索カラムの別名定義リスト
        #   
        # === 詳細
        #
        # 詳細は MakiTetsu::Enhaced::Search を参照
        #
        def enhanced_search(options = {})
          unless enhanced_search?
            cattr_accessor :search_columns
            cattr_accessor :search_order
            cattr_accessor :search_include
            cattr_accessor :search_aliases
            cattr_accessor :search_finder
            self.search_columns = options[:columns] || {}
            self.search_order   = options[:order]   || []
            self.search_include = options[:include] || nil
            self.search_aliases = options[:aliases] || {}
            self.search_finder  = options[:finder]  || :find
            validate_search_columns
          end

          include InstanceMethods
        end

        def enhanced_search? #:nodoc:
          self.included_modules.include?(InstanceMethods)
        end

        def validate_search_columns #:nodoc:
          self.search_columns.each do |column, type|
            unless VALID_SEARCH_TYPES.include?(type)
              raise ArgumentError, "Unknown search column type [#{type.to_s}]"
            end
            unless column_names.include?(column)
              unless self.search_aliases.keys.include?(column)
                raise ArgumentError, "Unknown column name [#{column}]"
              end
            end
          end
        end
      end

      module InstanceMethods #:nodoc:
        def self.included(base) #:nodoc:
          base.extend ClassMethods
        end

        module ClassMethods
          # === 概要
          #
          # enhanced_search によって生成される検索用のメソッド
          #
          # call-seq:
          #   search(options = {}) => Array
          #
          # === 使用例
          #
          #   search(:columns => {'name'     => 'Tom',
          #                       'age_from' => nil,
          #                       'age_to'   => 24,
          #                       'sex'      => 'F'})
          #
          # === 引数
          #
          # <tt>options</tt>::
          #   検索オプションを渡す。
          #   <tt>:columns</tt>::
          #     検索の値を項目毎にハッシュで渡します。
          #     enhanced_search で :match_* を指定したものは値を一つ、
          #     :including 指定した場合は配列で指定します。
          #     :*_scope を指定した場合は自動で _from, _to という検索値用のカラムが
          #     追加されるので、それぞれ上限値、下限値を設定します。
          #   <tt>:order</tt>::
          #     並び順を配列で指定します(MakiTetsu::Enhanced::Search::ClassMethods)。
          #   <tt>:additional_conditions</tt>::
          #     EnhancedSearch で表現しにくい conditions を直接渡します。
          #
          # === 戻り値
          # 
          # 検索にマッチしたレコードの検索結果を配列で返却します。
          #
          def search(options = {})
            validate_search_options(options)
            columns = options.delete(:columns) || {}
            order   = options.delete(:order)   || self.search_order
            additional_conditions = 
              options.delete(:additional_conditions) || nil
            
            conditions = build_search_conditions(columns)
            order_expression = nil
            order_expression = order.join(' ') unless order.empty?
            unless additional_conditions.blank?
              conditions[0] += " AND " unless conditions[0].empty?
              conditions[0] += "(#{additional_conditions.shift})"
              conditions += additional_conditions
            end

            find_options = {
              :conditions => conditions,
              :order => order_expression,
              :include => self.search_include
            }

            return self.send(self.search_finder,
                             :all, find_options.update(options))
          end

          private

          def validate_search_options(options)
            invalid_keys = [:conditions, :include]
            invalid_keys.each do |key|
              if options.has_key?(key)
                raise ArgumentError, "Search method cannot use [#{key}] key"
              end
            end
          end

          def build_search_conditions(columns)
            cond_s = []
            cond_v = []

            columns = fix_scope_values(columns)
            columns.each do |column, values|
              unless self.search_columns.keys.include?(column)
                raise ArgumentError, "Unknown column \"#{column}\" in settings"
              end

              next if values.nil? || values.empty? || values.blank?
              target = resolve_aliases(column)

              case self.search_columns[column]
              when :match_full
                cond_s << "(#{target}) = ?"
                cond_v << values
              when :match_partial
                cond_s << "(#{target}) LIKE ?"
                cond_v << "%#{values}%"
              when :closed_scope
                if values.kind_of? Array
                  min, max = values.first, values.last
                  min = nil if min.blank?
                  max = nil if max.blank?
                  if min || max
                    min = max if min.nil?
                    max = min if max.nil?
                    cond_s << "? <= (#{target})"
                    cond_v << min
                    cond_s << "(#{target}) <= ?"
                    cond_v << max
                  end
                else
                  raise ArgumentError, "Closed scope column's value must be array"
                end
              when :opened_scope
                if values.kind_of? Array
                  min, max = values.first, values.last
                  unless min.blank?
                    cond_s << "? <= (#{target})"
                    cond_v << min
                  end
                  unless max.blank?
                    cond_s << "(#{target}) <= ?"
                    cond_v << max
                  end
                else
                  raise ArgumentError, "Opened scope column's value must be array"
                end
              when :including
                cond_s << "(#{target}) IN (?)"
                cond_v << values
              end
            end

            conditions = cond_v.unshift(cond_s.map{|c| "(#{c})"}.join(" AND "))
            return nil if conditions.empty?
            return conditions
          end

          def resolve_aliases(column)
            if self.search_aliases.has_key?(column)
              return self.search_aliases[column]
            end
            return column
          end

          # :*_scope を内部表現に変換する
          def fix_scope_values(columns)
            result = {}
            columns.each do |key, value|
              if /(.*)_from$/ =~ key
                result[$1] = [nil, nil] if result[$1].nil?
                result[$1][0] = value
              elsif /(.*)_to$/ =~ key
                result[$1] = [nil, nil] if result[$1].nil?
                result[$1][1] = value
              else
                result[key] = value
              end
            end

            return result
          end
        end
      end
    end
  end
end
