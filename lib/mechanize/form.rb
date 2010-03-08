require 'mechanize/form/field'
require 'mechanize/form/file_upload'
require 'mechanize/form/button'
require 'mechanize/form/image_button'
require 'mechanize/form/radio_button'
require 'mechanize/form/check_box'
require 'mechanize/form/multi_select_list'
require 'mechanize/form/select_list'
require 'mechanize/form/option'

class Mechanize
  # =Synopsis
  # This class encapsulates a form parsed out of an HTML page.  Each type
  # of input fields available in a form can be accessed through this object.
  # See GlobalForm for more methods.
  #
  # ==Example
  # Find a form and print out its fields
  #  form = page.forms.first # => Mechanize::Form
  #  form.fields.each { |f| puts f.name }
  # Set the input field 'name' to "Aaron"
  #  form['name'] = 'Aaron'
  #  puts form['name']
  class Form
    attr_accessor :method, :action, :name

    attr_reader :fields, :buttons, :file_uploads, :radiobuttons, :checkboxes
    attr_accessor :enctype

    alias :elements :fields

    attr_reader :form_node
    attr_reader :page

    def initialize(node, mech=nil, page=nil)
      @enctype = node['enctype'] || 'application/x-www-form-urlencoded'
      @form_node        = node
      @action           = Util.html_unescape(node['action'])
      @method           = (node['method'] || 'GET').upcase
      @name             = node['name']
      @clicked_buttons  = []
      @page             = page
      @mech             = mech

      parse
    end

    # Returns whether or not the form contains a field with +field_name+
    def has_field?(field_name)
      ! fields.find { |f| f.name.eql? field_name }.nil?
    end

    alias :has_key? :has_field?

    def has_value?(value)
      ! fields.find { |f| f.value.eql? value }.nil?
    end

    def keys; fields.map { |f| f.name }; end

    def values; fields.map { |f| f.value }; end

    def submits  ; @submits   ||= buttons.select { |f| f.class == Submit   }; end
    def resets   ; @resets    ||= buttons.select { |f| f.class == Reset    }; end
    def texts    ; @texts     ||=  fields.select { |f| f.class == Text     }; end
    def hiddens  ; @hiddens   ||=  fields.select { |f| f.class == Hidden   }; end
    def textareas; @textareas ||=  fields.select { |f| f.class == Textarea }; end

    def submit_button?(button_name) !!  submits.find{|f| f.name == button_name}; end
    def reset_button?(button_name)  !!   resets.find{|f| f.name == button_name}; end
    def text_field?(field_name)     !!    texts.find{|f| f.name == field_name}; end
    def hidden_field?(field_name)   !!  hiddens.find{|f| f.name == field_name}; end
    def textarea_field?(field_name) !!textareas.find{|f| f.name == field_name}; end

    # Add a field with +field_name+ and +value+
    def add_field!(field_name, value = nil)
      fields << Field.new(field_name, value)
    end

    # This method sets multiple fields on the form.  It takes a list of field
    # name, value pairs.  If there is more than one field found with the
    # same name, this method will set the first one found.  If you want to
    # set the value of a duplicate field, use a value which is a Hash with
    # the key as the index in to the form.  The index
    # is zero based.  For example, to set the second field named 'foo', you
    # could do the following:
    #  form.set_fields( :foo => { 1 => 'bar' } )
    def set_fields(fields = {})
      fields.each do |k,v|
        case v
        when Hash
          v.each do |index, value|
            self.fields_with(:name => k.to_s).[](index).value = value
          end
        else
          value = nil
          index = 0
          [v].flatten.each do |val|
            index = val.to_i unless value.nil?
            value = val if value.nil?
          end
          self.fields_with(:name => k.to_s).[](index).value = value
        end
      end
    end

    # Fetch the value of the first input field with the name passed in
    # ==Example
    # Fetch the value set in the input field 'name'
    #  puts form['name']
    def [](field_name)
      f = field(field_name)
      f && f.value
    end

    # Set the value of the first input field with the name passed in
    # ==Example
    # Set the value in the input field 'name' to "Aaron"
    #  form['name'] = 'Aaron'
    def []=(field_name, value)
      f = field(field_name)
      if f.nil?
        add_field!(field_name, value)
      else
        f.value = value
      end
    end

    # Treat form fields like accessors.
    def method_missing(id,*args)
      method = id.to_s.gsub(/=$/, '')
      if field(method)
        return field(method).value if args.empty?
        return field(method).value = args[0]
      end
      super
    end

    # Submit this form with the button passed in
    def submit button=nil, headers = {}
      @mech.submit(self, button, headers)
    end

    # Submit form using +button+. Defaults
    # to the first button.
    def click_button(button = buttons.first)
      submit(button)
    end

    # This method is sub-method of build_query.
    # It converts charset of query value of fields into expected one.
    def proc_query(field)
      return unless field.query_value
      field.query_value.map{|(name, val)|
        [from_native_charset(name), from_native_charset(val.to_s)]
      }
    end
    private :proc_query

    def from_native_charset(str, enc=nil)
      if page
        enc ||= page.encoding
        Util.from_native_charset(str,enc) rescue str
      else
        str
      end
    end
    private :from_native_charset

    # This method builds an array of arrays that represent the query
    # parameters to be used with this form.  The return value can then
    # be used to create a query string for this form.
    def build_query(buttons = [])
      query = []

      fields().each do |f|
        qval = proc_query(f)
        query.push(*qval)
      end

      checkboxes().each do |f|
        if f.checked
          qval = proc_query(f)
          query.push(*qval)
        end
      end

      radio_groups = {}
      radiobuttons().each do |f|
        fname = from_native_charset(f.name)
        radio_groups[fname] ||= []
        radio_groups[fname] << f
      end

      # take one radio button from each group
      radio_groups.each_value do |g|
        checked = g.select {|f| f.checked}

        if checked.size == 1
          f = checked.first
          qval = proc_query(f)
          query.push(*qval)
        elsif checked.size > 1
          raise "multiple radiobuttons are checked in the same group!"
        end
      end

      @clicked_buttons.each { |b|
        qval = proc_query(b)
        query.push(*qval)
      }
      query
    end

    # This method adds a button to the query.  If the form needs to be
    # submitted with multiple buttons, pass each button to this method.
    def add_button_to_query(button)
      @clicked_buttons << button
    end

    # This method calculates the request data to be sent back to the server
    # for this form, depending on if this is a regular post, get, or a
    # multi-part post,
    def request_data
      query_params = build_query()
      case @enctype.downcase
      when /^multipart\/form-data/
        boundary = rand_string(20)
        @enctype = "multipart/form-data; boundary=#{boundary}"
        params = []
        query_params.each { |k,v| params << param_to_multipart(k, v) unless k.nil? }
        @file_uploads.each { |f| params << file_to_multipart(f) }
        params.collect { |p| "--#{boundary}\r\n#{p}" }.join('') +
          "--#{boundary}--\r\n"
      else
        Mechanize::Util.build_query_string(query_params)
      end
    end

    # Removes all fields with name +field_name+.
    def delete_field!(field_name)
      @fields.delete_if{ |f| f.name == field_name}
    end

    { :field        => :fields,
      :button       => :buttons,
      :file_upload  => :file_uploads,
      :radiobutton  => :radiobuttons,
      :checkbox     => :checkboxes,
    }.each do |singular,plural|
      eval(<<-eomethod)
          def #{plural}_with criteria = {}
            criteria = {:name => criteria} if String === criteria
            f = #{plural}.find_all do |thing|
              criteria.all? { |k,v| v === thing.send(k) }
            end
            yield f if block_given?
            f
          end

          def #{singular}_with criteria = {}
            f = #{plural}_with(criteria).first
            yield f if block_given?
            f
          end
          alias :#{singular} :#{singular}_with
        eomethod
    end

    private
    def parse
      @fields       = []
      @buttons      = []
      @file_uploads = []
      @radiobuttons = []
      @checkboxes   = []
      
      form_elements = [@fields, @buttons, @file_uploads, @radiobuttons, @checkboxes]
      
      # Find all input tags
      form_node.search('input').each do |node|
        #store array sizes so we can determine which one changed
        original_array_sizes = form_elements.map{|e| e.size}
        
        type = (node['type'] || 'text').downcase
        name = node['name']
        next if name.nil? && !(type == 'submit' || type =='button')
        case type
        when 'radio'
          @radiobuttons << RadioButton.new(node['name'], node['value'], !!node['checked'], self, node)
        when 'checkbox'
          @checkboxes << CheckBox.new(node['name'], node['value'], !!node['checked'], self, node)
        when 'file'
          @file_uploads << FileUpload.new(node['name'], nil)
        when 'submit'
          @buttons << Submit.new(node['name'], node['value'], self)
        when 'button'
          @buttons << Button.new(node['name'], node['value'], self)
        when 'reset'
          @buttons << Reset.new(node['name'], node['value'], self)
        when 'image'
          @buttons << ImageButton.new(node['name'], node['value'], self)
        when 'hidden'
          @fields << Hidden.new(node['name'], node['value'] || '', self)
        when 'text'
          @fields << Text.new(node['name'], node['value'] || '')
        when 'textarea'
          @fields << Textarea.new(node['name'], node['value'] || '')
        else
          @fields << Field.new(node['name'], node['value'] || '')
        end
        
        #find the array that has been modified, and take the last element added to it...
        array_sizes = form_elements.map{|e| e.size}
        form_element = form_elements[original_array_sizes.zip(array_sizes).map{|x|x[1]-x[0]}.index(1)].last
        #...and map it to mechanize
        node.map2mechanize(@mech, form_element)    
      end
      

      # Find all textarea tags
      form_node.search('textarea').each do |node|
        next if node['name'].nil?
        @fields << Field.new(node['name'], node.inner_text)
        node.map2mechanize(@mech, @fields.last)
      end

      # Find all select tags
      form_node.search('select').each do |node|
        next if node['name'].nil?
        if node.has_attribute? 'multiple'
          @fields << MultiSelectList.new(node['name'], node, @mech)
          node.map2mechanize(@mech, @fields.last)
        else
          @fields << SelectList.new(node['name'], node, @mech)
          node.map2mechanize(@mech, @fields.last)
        end
      end

      # Find all submit button tags
      # FIXME: what can I do with the reset buttons?
      form_node.search('button').each do |node|
        type = (node['type'] || 'submit').downcase
        next if type == 'reset'
        @buttons << Button.new(node['name'], node['value'], node)
        node.map2mechanize(@mech, @buttons.last)
      end
    end

    def rand_string(len = 10)
      chars = ("a".."z").to_a + ("A".."Z").to_a
      string = ""
      1.upto(len) { |i| string << chars[rand(chars.size-1)] }
      string
    end

    def mime_value_quote(str)
      str.gsub(/(["\r\\])/){|s| '\\' + s}
    end

    def param_to_multipart(name, value)
      return "Content-Disposition: form-data; name=\"" +
        "#{mime_value_quote(name)}\"\r\n" +
        "\r\n#{value}\r\n"
    end

    def file_to_multipart(file)
      file_name = file.file_name ? ::File.basename(file.file_name) : ''
      body =  "Content-Disposition: form-data; name=\"" +
        "#{mime_value_quote(file.name)}\"; " +
        "filename=\"#{mime_value_quote(file_name)}\"\r\n" +
        "Content-Transfer-Encoding: binary\r\n"

      if file.file_data.nil? and ! file.file_name.nil?
        file.file_data = ::File.open(file.file_name, "rb") { |f| f.read }
        file.mime_type = WEBrick::HTTPUtils.mime_type(file.file_name,
                                                      WEBrick::HTTPUtils::DefaultMimeTypes)
      end

      if file.mime_type != nil
        body << "Content-Type: #{file.mime_type}\r\n"
      end

      body <<
        if file.file_data.respond_to? :read
          "\r\n#{file.file_data.read}\r\n"
        else
          "\r\n#{file.file_data}\r\n"
        end

      body
    end
  end
end
