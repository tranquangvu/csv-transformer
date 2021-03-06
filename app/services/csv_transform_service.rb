require 'csv'

class CsvTransformService
  attr_accessor :file_path, :imported_rows, :date, :removal_date

  ORIGIN_CSV_HEADERS = [
    :billing_first_name,
    :billing_last_name,
    :billing_email,
    :billing_phone,
    :shipping_address_1,
    :shipping_address_2,
    :shipping_postcode,
    :shipping_city,
    :shipping_state,
    :customer_note,
    :line_items,
    :shipping_items,
    :order_notes,
    :download_permissions_granted,
    :billing_country,
    :billing_company,
    :billing_address_1,
    :billing_address_2,
    :billing_city,
    :billing_state,
    :billing_postcode,
    :delivery_date,
    :delivery_time,
    :shipping_first_name,
    :shipping_last_name,
    :shipping_company,
    :shipping_country,
    :order_comments,
    :order_date
  ]

  ORDER_RESULT_CSV_HEADERS = [
    'ID',
    'Latitude',
    'Longitude',
    'Address',
    'From',
    'To',
    'Duration',
    'Notes',
    'Notes 2',
    'Load',
    'Types',
    'Phone'
  ]

  LOADING_RESULT_CSV_HEADERS = [
    'Item',
    'Quantity'
  ]

  CSV_RESULT_METHODS = [
    :csv_order_results,
    :csv_same_date_order_results,
    :csv_loading_results,
    :csv_removal_results
  ]

  OTHER_ITEM_COUNTER_METHODS = [
    :tree_service_setup_key_value,
    :tree_stand_key_value,
    :tree_food_key_value,
    :tree_wreath_key_value,
    :tree_light_key_value,
  ]

  def initialize(file_path, date, removal_date)
    @date = Date.parse(date) rescue nil
    @removal_date = Date.parse(removal_date) rescue nil
    @file_path = file_path
    @imported_rows = []

    CSV.foreach(file_path, headers: ORIGIN_CSV_HEADERS, encoding: 'ISO-8859-1') do |row, index|
      next if index == 0
      @imported_rows << row
    end

    @imported_rows.map! do |row|
      row[:delivery_date] = Date.parse(row[:delivery_date]) rescue nil
      row[:order_date] = Date.parse(row[:order_date]) rescue nil
      row
    end
  end

  def result
    @compressed_filestream = Zip::ZipOutputStream.write_buffer do |zos|
      CSV_RESULT_METHODS.each do |method_name|
        file_name, content = self.send(method_name)
        zos.put_next_entry file_name
        zos.print content
      end
    end
    @compressed_filestream.rewind
    @compressed_filestream
  end

  def csv_order_results
    [file_name_with_time_prefix(@date, 'orders.csv'), csv_orders_generater(order_results)]
  end

  def csv_same_date_order_results
    [file_name_with_time_prefix(@date, 'same_date_orders.csv'), csv_orders_generater(same_date_order_results)]
  end

  def csv_loading_results
    csv_content = CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << LOADING_RESULT_CSV_HEADERS
      loading_results.each do |key, value|
        csv << [key, value]
      end
    end
    [file_name_with_time_prefix(@date, 'loading_results.csv'), csv_content]
  end

  def csv_removal_results
    [file_name_with_time_prefix(@removal_date, 'removals.csv'), csv_removal_generater(removal_results)]
  end

  def order_results
    @order_results ||= imported_rows.select do |data_row|
      data_row[:delivery_date] && @date && data_row[:delivery_date] == @date
    end
  end

  def same_date_order_results
    @same_date_order_results ||= order_results.select do |data_row|
      data_row[:delivery_date] && data_row[:order_date] && data_row[:delivery_date] == data_row[:order_date]
    end
  end

  def loading_results
    return @loading_list_results if @loading_list_results

    @loading_list_results = {}

    # main item count
    order_results.each do |data_row|
      name = name_from_line_item(data_row[:line_items])
      quantity = quantity_from_line_item(data_row[:line_items])
      tree_size, size_unit = tree_size_unit_from_line_item(data_row[:line_items])

      main_item_key = "#{name} #{tree_size} #{size_unit}"
      @loading_list_results[main_item_key] = @loading_list_results[main_item_key] ?
        @loading_list_results[main_item_key] + quantity : quantity
    end

    # others item count
    order_results.each do |data_row|
      OTHER_ITEM_COUNTER_METHODS.each do |method|
        item_key, item_value = self.send(method, data_row[:line_items])
        if item_key && item_value && item_value > 0
          @loading_list_results[item_key] = @loading_list_results[item_key] ?
            @loading_list_results[item_key] + item_value : item_value
        end
      end
    end

    @loading_list_results.sort.to_h
  end

  def removal_results
    @removal_results ||= imported_rows.select do |data_row|
      data_row[:line_items] && @removal_date &&
        data_row[:line_items].include?("REMOVAL DATE=#{@removal_date.strftime('%m/%d/%Y')}")
    end
  end

  private

  # csv orders builder helpers
  def csv_orders_generater(data_list)
    CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << ORDER_RESULT_CSV_HEADERS
      data_list.each_with_index do |row, index|
        csv << [build_csv_id(row, index + 1), nil, nil, build_csv_address(row), build_csv_from(row),
          build_csv_to(row), 15, build_csv_notes(row), nil, 1, nil, row[:billing_phone]]
      end
    end
  end

  def csv_removal_generater(data_list)
    CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << ORDER_RESULT_CSV_HEADERS
      data_list.each_with_index do |row, index|
        csv << [build_csv_id(row, index + 1), nil, nil, build_csv_address(row), build_csv_removal_from(row),
          build_csv_removal_to(row), 15, build_csv_removal_notes(row), nil, 1, nil, row[:billing_phone]]
      end
    end
  end

  def build_csv_id(row, index)
    "#{index}_#{row[:billing_first_name]}_#{row[:billing_last_name]}"
  end

  def build_csv_address(row)
    # return address with country is fixed to USA
    "#{row[:shipping_address_1]}, #{row[:shipping_city]}, #{row[:shipping_state]} #{row[:shipping_postcode]}, USA"
  end

  def build_csv_from(row)
    convert_12_to_24_hr(row[:delivery_time].split('-').first.delete(' '))
  end

  def build_csv_removal_from(row)
    convert_12_to_24_hr(row[:line_items].match(/REMOVAL TIME=([^,]*)?/)[1].split('-').first.delete(' '))
  end

  def build_csv_to(row)
    convert_12_to_24_hr(row[:delivery_time].split('-').last.delete(' '))
  end

  def build_csv_removal_to(row)
    convert_12_to_24_hr(row[:line_items].match(/REMOVAL TIME=([^,]*)?/)[1].split('-').last.delete(' '))
  end

  def build_csv_notes(row)
    notes              = []
    customer_note      = row[:customer_note]
    shipping_address_2 = row[:shipping_address_2] ? "Apt: #{row[:shipping_address_2]}" : nil

    # main item count
    tree_name = name_from_line_item(row[:line_items])
    tree_quantity = quantity_from_line_item(row[:line_items])
    tree_size, size_unit = tree_size_unit_from_line_item(row[:line_items])
    notes << "#{tree_name} #{tree_size} #{size_unit} (#{tree_quantity})"

    # Other items
    OTHER_ITEM_COUNTER_METHODS.each do |method|
      item_key, item_value = self.send(method, row[:line_items])
      notes << "#{item_key} (#{item_value})".gsub(',', '-') if item_key && item_value && item_value > 0
    end

    [shipping_address_2, notes.join(', '), customer_note].compact.join(' | ')
  end

  def build_csv_removal_notes(row)
    notes              = []
    customer_note      = row[:customer_note]
    shipping_address_2 = row[:shipping_address_2] ? "Apt: #{row[:shipping_address_2]}" : nil

    item_key, item_value = tree_removal_key_value(row[:line_items])
    notes << "#{item_key} (#{item_value})".gsub(',', '-') if item_key && item_value && item_value > 0

    [shipping_address_2, notes.join(', '), customer_note].compact.join(' | ')
  end

  # common helpers
  def convert_12_to_24_hr(string_time)
    Time.strptime(string_time, "%I%P").strftime("%H:%M")
  end

  def file_name_with_time_prefix(date, file_name)
    "#{date.strftime('%Y%m%d')}_#{file_name}"
  end

  def meta_data_converter(meta)
    return [] unless meta

    result = []
    splited_meta = meta.split(',')
    splited_meta.each_with_index do |v, i|
      if v.include?('=')
        result << (!result.last || result.last.include?('=') ? v : [result.pop, v].join(','))
      else
        last_result = result.last

        if !last_result ||
          last_result.downcase.include?('=no=') || last_result.downcase.include?('=yes=') ||
            last_result.downcase.include?('=no,') || last_result.downcase.include?('=yes')
          result << v
        else
          result << [result.pop, v].join(',')
        end
      end
    end
    result.map(&:strip)
  end

  def meta_data_from_line_items(line_item, result_include_props: false)
    props       = line_item.split('|')
    meta_index  = props.each_index.find { |i| props[i].include?('meta:') }
    meta_value  = props.delete_at(meta_index).split(':').last.strip

    if result_include_props
      return [props, meta_data_converter(meta_value)]
    end

    meta_data_converter(meta_value)
  end

  def quantity_from_line_item(line_item)
    return unless line_item
    line_item.match(/quantity:(\d+)?/)[1].to_i
  end

  def name_from_line_item(line_item)
    return unless line_item
    line_item.match(/name:([^\|]+)?/)[1]
  end

  def tree_size_unit_from_line_item(line_item)
    return unless line_item

    size_string, size_unit = line_item.match(/choose-your-tree-size([^,]*)?=([^,]*)?/)[2].split
    [size_string.to_i, size_unit]
  end

  def tree_service_setup_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('Christmas Tree Set-Up Service') }

    return unless meta_key_value

    value_number = meta_key_value.downcase.exclude?('=no') ? 1 : 0
    spliter      = value_number == 1? '=yes' : '=no'

    [meta_key_value.downcase.split(spliter).first.titleize, value_number]
  end

  def tree_stand_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('Christmas Tree Stand for Your Tree') }

    return unless meta_key_value

    value_number = meta_key_value.downcase.exclude?('=no') ? 1 : 0
    spliter      = value_number == 1? '=yes' : '=no'

    [meta_key_value.downcase.split(spliter).first.titleize, value_number]
  end

  def tree_food_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('All-Natural Christmas Tree Food') }

    return unless meta_key_value

    spliters       = meta_key_value.split('=')
    key, value     = [spliters.pop, spliters.join('=')].reverse
    value_number   = human_counter_to_number(value.downcase.split.first)

    [key.titleize, value_number]
  end

  def tree_wreath_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('Christmas Wreath') }

    return unless meta_key_value

    spliters       = meta_key_value.split('=')
    key, value     = [spliters.pop, spliters.join('=')].reverse
    value_number   = human_counter_to_number(value.downcase.split.first)

    [key.titleize, value_number]
  end

  def tree_light_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('Christmas Tree Lights') }

    return unless meta_key_value

    spliters       = meta_key_value.split('=')
    key, value     = [spliters.pop, spliters.join('=')].reverse
    value_number   = value.to_i

    [key.titleize, value_number]
  end

  def tree_removal_key_value(line_item)
    return unless line_item

    meta_data      = meta_data_from_line_items(line_item)
    meta_key_value = meta_data.find { |d| d.include?('Christmas Tree Removal') }

    return unless meta_key_value

    value_number = meta_key_value.downcase.exclude?('=no') ? 1 : 0
    spliter      = value_number == 1? '=yes' : '=no'

    [meta_key_value.downcase.split(spliter).first.titleize, value_number]
  end

  def human_counter_to_number(s)
    converter = {
      'one'   => 1,
      'two'   => 2,
      'three' => 3,
      'four'  => 4,
      'five'  => 5,
      'six'   => 6,
      'seven' => 7,
      'eight' => 8,
      'nine'  => 9,
      'ten'   => 10
    }
    converter.fetch(s.to_s, 0)
  end
end
