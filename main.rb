# coding: utf-8
require 'kconv'
require 'net/http'
require 'active_support'
require 'active_support/core_ext'
require 'nokogiri'

# メニューをスクレイピングで取得
class ScrapingMenus
  # 取得する月 this_month,next_month
  # 取得するメニューのタイプ a1,a2,b1,b2,hai
  def initialize(month: 'this_month', menu_type: nil)
    @menus     = []
    @month     = month
    @menu_type = menu_type
    # Nokogiri単体ではPostが送れないため利用
    # メニュータイプが一致すればareaが異なっても
    # 同じデータが返るのでkantoに固定
    res        = Net::HTTP.post_form(
      URI.parse('http://www.dnet.gr.jp/menulist/search/index.php'),
      area:  'kanto',
      stuki: @month,
      ryou:  @menu_type
    )
    @doc       = Nokogiri.HTML(res.body.toutf8)
    perse_html
  end

  attr_accessor :menus

  def check_month
    if @month == 'next_month'
      Time.current.next_month
    else
      Time.current
    end
  end

  def create_menu(tds)
    time = check_month
    date = Date.new(time.year, time.month, tds[0])
    @menus << {
      menu_type:   @menu_type,
      date:        date,
      breakfast_j: tds[1],
      breakfast_w: tds[2],
      dinner:      tds[3]
    }
  end

  def perse_html
    @doc.search('td.result_main tr').each do |tr|
      if tr['class'] == 'holiday'
        tds = split_element_to_array(tr.children)
        next if tds[0].blank?
        create_menu tds
      else
        tds = tr.children
        create_menu split_element_to_array(tds) unless tds[1].text.to_i.zero?
      end
    end
  end

  def split_element_to_array(elements)
    arr = []
    (1..9).step(2) do |i|
      arr << elements[i]
    end
    arr.map!(&:text)
    change_star_to_comma(arr)
  end

  # ☆を,に変更する
  def change_star_to_comma(arr)
    result = arr[2..4].map do |v|
      v.gsub('★', '・') unless v.blank?
    end
    [arr[0].to_i, *result]
  end

  # 取得したい月を引数にとる
  # this_month or next_month
  # デフォルトは今月
  def self.generate_menus(month: 'this_month')
    results = []
    %w(a1 a2 b1 b2 hai).each do |type|
      results << new(month: month, menu_type: type)
    end
    # 日毎のデータに分解する
    results.map { |v| v.menus.flatten }.flatten
  end
end

menus = ScrapingMenus.generate_menus
# menus = ScrapingMenus.generate_menus(month: 'next_month')
menus.each do |menu|
  puts menu
end
