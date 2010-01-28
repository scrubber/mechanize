module Nokogiri
  module XML
    class Node 
      def check
        @mech.nokogiri2mechanize[self].check
      end
      
      def uncheck
        @mech.nokogiri2mechanize[self].uncheck
      end
            
      def click
        @mech.nokogiri2mechanize[self].click
      end
      
      def fill_textfield(value)
        @mech.nokogiri2mechanize[self].value = value
      end
          
      def select_option
        @mech.nokogiri2mechanize[self].select
      end
  
      def submit_form
        mech_node = @mech.nokogiri2mechanize[self]
        @mech.submit(mech_node.form, mech_node)
      end      
      
      def map2mechanize(mech, mech_node)
        mech.nokogiri2mechanize[self] = mech_node
        @mech = mech
      end      
    end
  end
end  