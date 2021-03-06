require "amqp"

$stdout.sync = true

EventMachine.run do
  connection = AMQP.connect
  connection.after_connection_interruption do |connection, settings|
    # reconnect in 10 seconds, without enforcement
    connection.reconnect(false, 10)
  end
  channel    = AMQP::Channel.new(connection)
  channel.auto_recovery = true

  requests_queue = channel.queue("amqpgem.examples.services.time", :exclusive => true, :auto_delete => true)
  requests_queue.subscribe(:ack => true) do |metadata, payload|
    puts "[requests] Got a request #{metadata.message_id}. Sending a reply..."
    channel.default_exchange.publish(Time.now.to_s,
                                     :routing_key    => metadata.reply_to,
                                     :correlation_id => metadata.message_id,
                                     :immediate      => true,
                                     :mandatory      => true)
    metadata.ack
  end

  Signal.trap("INT") { connection.close { EventMachine.stop } }
  Signal.trap("TERM") { connection.close { EventMachine.stop } }
end
