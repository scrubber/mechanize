class Mechanize
  class Form
    # This class represents a Submit button in a form.
    class Button < Field 
      attr_reader :form
      
      def initialize(name, value, form) 
        @form = form
        super(name, value)        
      end      
    end
    
    class Submit < Button; end
    
    class Reset  < Button; end
  end
end

