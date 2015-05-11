module SlangerHelperMethods
  class HaveAttributes
    attr_reader :messages, :attributes
    def initialize attributes
      @attributes = attributes
    end

    CHECKS = %w(first_event last_event last_data count)

    def matches?(messages)
      @messages = messages
      @failures = []

      check_connection_established if attributes[:connection_established]
      check_id_present             if attributes[:id_present]

      CHECKS.each { |a| attributes[a.to_sym] ?  check(a) : true }

      @failures.empty?
    end

    def check message
      attribute(message) == attributes[message.to_sym] or @failures << message
    end

    def failure_message
      @failures.map {|f| "expected #{f} to equal #{attributes[f.to_sym].inspect} but got #{attribute(f).inspect}\n" }.join("\n") + "messages: #{messages}"
    end


    def attribute(name)
      send(name)
    rescue NoMethodError
      nil
    end
    private

    def check_connection_established
      if first_event != 'pusher:connection_established'
        @attributes.delete :connection_established
        @failures << :connection_established
      end
    end

    def check_id_present
      data = JSON.parse messages.first["data"]

      if data["socket_id"] == nil
        @attributes.delete :id_present
        @failures << :id_present
      end
    end

    def first_event
      messages.first['event']
    end

    def last_event
      messages.last['event']
    end

    def last_data
      messages.last['data']
    end

    def count
      messages.length
    end
  end

  def have_attributes attributes
    HaveAttributes.new attributes
  end
end
