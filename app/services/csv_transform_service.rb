require 'csv';

class CsvTransformService
  attr_accessor :file_path, :imported_rows, :date

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

  RESULT_CSV_HEADERS = [
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

  CSV_RESULT_METHODS = ['csv_order_results', 'csv_same_date_order_results']

  def initialize(file_path, date)
    @date = Date.parse(date) rescue nil
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

  private

  # csv orders builder helpers
  def csv_orders_generater(data_list)
    CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << RESULT_CSV_HEADERS
      data_list.each_with_index do |row, index|
        csv << [build_csv_id(row, index + 1), nil, nil, build_csv_address(row), build_csv_from(row),
          build_csv_to(row), 10, build_csv_notes(row), nil, 1, nil, row[:billing_phone]]
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

  def build_csv_to(row)
    convert_12_to_24_hr(row[:delivery_time].split('-').last.delete(' '))
  end

  def build_csv_notes(row)
    props       = row[:line_items].split('|')
    meta_index  = props.each_index.find { |i| props[i].include?('meta:') }
    meta_value  = props.delete_at(meta_index).split(':').last.strip
    meta_data   = convert_meta_data(meta_value)

    props << meta_data.select { |md| md.split('=').last.downcase.exclude?('no') }
    props.join("\n")
  end

  # common helpers
  def convert_12_to_24_hr(string_time)
    Time.strptime(string_time, "%I%P").strftime("%H:%M")
  end

  def file_name_with_time_prefix(date, file_name)
    "#{date.strftime('%Y%m%d')}_#{file_name}"
  end

  def convert_meta_data(meta_value)
    return [] unless meta_value

    result = []
    meta_value.split(',').each_with_index do |v, i|
      if v.include?('=')
        result << v
      else
        result << [result.pop, v].join(',')
      end
    end
    result.map(&:strip)
  end
end
