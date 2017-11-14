class HomeController < ApplicationController
	require 'socket'

	def index

	end

	def senzor
		host = 'localhost'
		sensor_num = params[:sensor_number].to_i - 1
		sensor_PORT = 1999 + params[:sensor_number].to_i
		@time_created = Time.now

		# Static configuration
		ports = [2000, 2001, 2002, 2003]
		ports.delete(sensor_PORT)
		times_sent = [0, 0, 0 ,0]
		jitter = (Random.rand(400)-200)/1000.to_f
		time_millis = current_time_millis(@time_created.to_i*1000, jitter)

		recieved_packages = {
			2000 => [],
			2001 => [],
			2002 => [],
			2003 => []
		}

		readings_hash = {
			2000 => {},
			2001 => {},
			2002 => {},
			2003 => {}
		}


		# Read sensor data every second
		Thread.new do 
			sleep(1.seconds)
			puts "Listening on #{sensor_PORT}\n"
			socket = Socket.new(Socket::AF_INET, Socket::SOCK_DGRAM, 0)
			socket.bind(Addrinfo.udp('', sensor_PORT))

			while true
				sock = UDPSocket.new
				ready_sockets = IO.select([socket])
				readable_sockets = ready_sockets[0]

				readable_sockets.each do |s|
					data = s.recvfrom(1024)
					sender_data = data[0].squish.split(',')
					sender_readings = sender_data[0]
					sender_PORT = sender_data[1].to_i
					sender_type = sender_data[2]
					sender_time_millis = sender_data[3].to_i

					sender_times_sent = []
					sender_times_sent << sender_data[4].split('/')[0].to_i
					sender_times_sent << sender_data[4].split('/')[1].to_i
					sender_times_sent << sender_data[4].split('/')[2].to_i
					sender_times_sent << sender_data[4].split('/')[3].to_i

					if sender_type.match(/data/)	

						if readings_hash[sender_PORT][sender_time_millis].blank?
							readings_hash[sender_PORT][sender_time_millis] = [sender_readings, sender_times_sent]
							times_sent[sensor_num] += 1
							pos = sender_PORT - 2000
							times_sent = calculate_times_sent(sender_times_sent, times_sent, pos)
						end

						reply = "#{sender_readings},#{sensor_PORT},reply,#{sender_time_millis},#{sender_times_sent[0]}/#{sender_times_sent[1]}/#{sender_times_sent[2]}/#{sender_times_sent[3]}"
						simple_simulate_datagram_socket(sender_PORT, 0, 1000, reply, host, sock)

					elsif sender_type.match(/reply/)

						if !recieved_packages[sender_PORT].include?(sender_time_millis.to_i)
							recieved_packages[sender_PORT].push(sender_time_millis.to_i)
							times_sent[sensor_num] += 1
							pos = sender_PORT - 2000
							times_sent = calculate_times_sent(sender_times_sent, times_sent, pos)
						end
					end
				end
			end

			socket.close
		end

		# Analyze every 5 sec
		Thread.new do 
			while true
				sleep(5.seconds)
				space = sensor_num * 50
				puts " "*space + "Trenutna analiza za #{sensor_PORT}"

				if false
					sorted_by_timestamp = {}
					readings_hash.each do |port, val|
						val.to_a.last(5).to_h.each do |timestamp, data|
							sorted_by_timestamp[timestamp] = data
						end 
					end

					sorted_by_timestamp.sort.to_h.each do |timestamp, data|
						puts " "*space + "TIMESTAMP: #{timestamp}: #{data[0]}, #{data[1]}\n"
					end
				else
					sorted_by_vectors = {}
					readings_hash.each do |port, val|
						val.to_a.last(5).to_h.each do |timestamp, data|
							vector = data[1]
							sorted_by_vectors[timestamp] = [data[0], vector, vector.sum]
						end
					end

					sorted_by_vectors.sort_by {|timestamp, data| data[2]}.to_h.each do |timestamp, data|
						puts " "*space + "VECTOR: #{data[2]}: #{data[0]}, #{data[1]}, #{timestamp}\n"
					end
				end
			end
		end

		sleep(5.seconds)
		while true
			sleep(1.seconds)
			time_millis = current_time_millis(@time_created.to_i*1000, jitter)
			readings_hash[sensor_PORT][time_millis] = [simulate_sensor_reading(@time_created), times_sent]
			times_sent[sensor_num] += 1

			# Wait until everyone gets the package
			while !recieved_packages[ports[0]].include?(time_millis.to_i) || 
				!recieved_packages[ports[1]].include?(time_millis.to_i) || 
				!recieved_packages[ports[2]].include?(time_millis.to_i) 

				s = UDPSocket.new
				message = "#{readings_hash[sensor_PORT][time_millis][0]},#{sensor_PORT},data,#{time_millis},#{times_sent[0]}/#{times_sent[1]}/#{times_sent[2]}/#{times_sent[3]}"

				# Resend to the ones who don't have it
				if !recieved_packages[ports[0]].include?(time_millis.to_i)
					simple_simulate_datagram_socket(ports[0], 25, 1000, message, host, s)
				end

				if !recieved_packages[ports[1]].include?(time_millis.to_i)
					simple_simulate_datagram_socket(ports[1], 25, 1000, message, host, s)
				end

				if !recieved_packages[ports[2]].include?(time_millis.to_i)
					simple_simulate_datagram_socket(ports[2], 25, 1000, message, host, s)
				end

				sleep(2.seconds)
			end
		end
	end

	# From the EmulatedSystemClock example class
	def current_time_millis(time_created, jitter)
		current = Time.now.to_i*1000
		diff = current - time_created
		coef = diff/1000
		return time_created + (diff * (1+jitter) ** coef).round
	end

	# From the SimpleSimulateDatagramSocket example class
	def simple_simulate_datagram_socket(port, loss_rate, average_delay, message, host, socket)
		loss = Random.rand(10000)/100.to_f

		if loss > loss_rate 
			average_delay = 1000
			delay = Random.rand(average_delay*2)/1000.to_f

			Thread.new do
				sleep(delay.seconds)
				socket.send(message, 0, host, port)
				socket.close
			end
		else
			return false
		end
	end

	def simulate_sensor_reading(time_created)
		# Int redni_broj = (broj_aktivnih_sekundi % 100) + 2
		rand_line_num = (((Time.now - @time_created.to_time + Random.rand(20)).to_i % 100) + 2).to_i#((Time.now - time_created.to_time).to_i % 100) + 2

		line_num = 1
		File.open('mjerenja.txt', 'r') do |f|
			f.each_line do |line|
				if line_num == rand_line_num
					@co_reading = line.squish.gsub(',,', ', ,').split(',')[3]
					return 0 if @co_reading.blank?

					return @co_reading
				end

				line_num += 1
			end
		end
	end

	def calculate_times_sent(sender_V, times_V, pos)
		times_sent = times_V

		if sender_V[pos].to_i > times_V[pos]
			times_sent[pos] = sender_V[pos].to_i
		else
			times_sent[pos] = times_V[pos]
		end

		return times_sent
	end
end
