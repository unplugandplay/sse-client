require "http/client"

module SSE
  class EventSource
    # Get API url
    getter :url
    # Get ready state
    getter :ready_state

    # The connection has not yet been established, or it was closed and the user agent is reconnecting.
    CONNECTING = 0
    # The user agent has an open connection and is dispatching events as it receives them.
    OPEN       = 1
    # The connection is not open, and the user agent is not trying to reconnect. Either there was a fatal error or the close() method was invoked.
    CLOSED     = 2

    def initialize(url : String, query :   Hash(String, String)  = Hash(String, String).new , headers :   Hash(String, String |  Hash(String, String) )  =  Hash(String, String |  Hash(String, String) ).new  ) #, before_execution_proc = nil )
    #def initialize(url : String ) #, before_execution_proc = nil )
      @url = url
      #query =  Hash(String, String  ).new
     @headers = headers
      #@headers = Hash(String, String  ).new

     @headers["params"] = query
     #@headers : Hash(String, Hash(String, String  )  )
     #@headers = {params: query}


      @ready_state = CLOSED
      #@before_execution_proc = nil

      @opens = [] of Proc(Void)
      @errors = [] of Proc(HTTP::Client::Response, HTTP::Client::Response)
      @messages = [] of Proc(String, String)
      @on_procs = Hash(String, Array(Proc(String, String))).new
    end

    def start
      @ready_state = CONNECTING
      listen
    end

    def open(&block)
      @opens << block
    end

    def on(name, &block : String -> _)
      @on_procs[name] ||= [] of Proc(String, String)
      p "on"
      p name
      @on_procs[name] << block
    end

    def message(&block : String)
      @messages << block
    end

    def error(&block)
      @errors << block
    end

    private def listen


      #conn = RestClient::Request.execute(method: :get,
      #                              url: @url,
      #                              headers: @headers,
      #                              block_response: block,
      #                              before_execution_proc: @before_execution_proc)

      response = HTTP::Client.get(@url, headers: HTTP::Headers.new)  do |response|

        handle_open
        p "response : #{response.inspect} "
        case response.status_code

        when 200

          fields = Hash(String, String).new("")

          while chunk = response.body_io.gets
            if chunk.blank?
              p "sending to procs"
              handle_stream fields
              fields = Hash(String, String).new("")
            else
              #p "chunk? #{chunk}"
              field, value = chunk.split(":")
              value = value.lstrip



              p "field: #{field}"
              p "value: #{value}"
              next unless value
              if field != "data" || !fields.has_key?("data")
                fields[field] = value
              else
                fields["data"] = fields["data"] + "\n" + value
              end

            end

          end
          p "****"
          close
        else
          handle_error response
        end
      end
    end

    def handle_stream(fields)
      data = fields["data"]
      name = fields["event"]

      p "name: #{name}"
      return if data.empty?

      # in all cases we sent messages procs
      @messages.each { |message| message.call(data) }

      # on requested we send on procs
      #p @on_procs.keys
      p !name.blank?
      @on_procs[name].each { |message| p "on_procs #{message.inspect} #{name} !" ; message.call(data) } if !name.blank?  && @on_procs.has_key?(name)

    end

    def handle_open
      @ready_state = OPEN
      p "handle_open"
      p @opens.size
      p @opens.inspect
      @opens.each { |open| open.call() }
    end

    def handle_error(response)
      close
      @errors.each { |error| error.call(response) }
    end

    def close
      p "closing"
      @ready_state = CLOSED
    end
  end
end
