module Athens
  class Connection
    attr_reader :database_name

    def initialize(database_name)
      @database_name = database_name
      @client = Aws::Athena::Client.new
    end

    def execute(query)
      resp = @client.start_query_execution(
        query_string: query,
        query_execution_context: context,
        result_configuration: result_config
      )


      result = nil

      while true
        result = @client.get_query_execution(query_execution_id: resp.query_execution_id)

        state = result.query_execution.status.state

        if state == 'SUCCEEDED'
          break
        elsif state == 'FAILED'
          raise QueryFailedError.new(result.query_execution.status.state_change_reason)
          break
        elsif state == 'CANCELLED'
          raise QueryCancelledError.new(result.query_execution.status.state_change_reason)
          break
        end

        # Wait a bit and check again
        sleep(0.25)
      end

      # If here it was successful, grab the results and return those

      query_result = @client.get_query_results({query_execution_id: result.query_execution.query_execution_id})

      return query_result
    end

    private

      def context 
        Aws::Athena::Types::QueryExecutionContext.new(database: @database_name)
      end

      def result_config
        Aws::Athena::Types::ResultConfiguration.new(
          output_location: Athens.configuration.output_location,
          encryption_configuration: {
            encryption_option: "SSE_S3"
          }
        )
      end    
  end
end