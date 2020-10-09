require 'telegram_bot'
require 'open-uri'
require 'timeout'
require 'thread'

$apps_array = [] # массив приложений

class App
  app_state = 0 #0 - не вышло, 1 - вышло, 2 - забанили
  app_name = "none"
  app_message = ""

  attr_reader :app_name
  attr_reader :app_state
  attr_accessor :app_message

  def initialize(package_name)
    @app_name = package_name
    @app_message = ""
    counter = 0
    package_name.split('').each { |c|
      if c == '.' then
        counter += 1
      end
    }
    if counter == 2 then
      begin
        @link = 'https://play.google.com/store/apps/details?id=' + package_name
        $apps_array.push(self)
      end
    else
      @link = package_name
    end
    @app_state = 0
  end

  def make_the_request
    begin
      file = open(@link)
      contents = file.read
      if @app_state < 1 then
        @app_state += 1
      end
      "Приложение #{@app_name} доступно в Play Market. Ссылка: #{@link}"
    rescue OpenURI::HTTPError
      case @app_state
      when 0
        "Приложение #{@app_name} еще не вышло или недоступно в Play Market."
      when 1
        "Уважаемые партнеры! Приложение #{@app_name} заблокировано."
      end
    rescue StandardError
        "Ссылка #{@link} указана неверно. Введите верные данные."
    end
  end
end

token = '1324909471:AAF5loszIwzSQIUM_6rPzvXcXMfvS17Kpuc'
saved_chat_id = 0
bot = TelegramBot.new(token: token)

Thread.new do
  loop do
    sleep 300
    if $apps_array.length() > 0 then
      $apps_array.each do |app|
        app_text = app.make_the_request
        if app_text != nil and app_text != app.app_message then
          app.app_message = app_text
          channel = TelegramBot::Channel.new(id: saved_chat_id)
          message = TelegramBot::OutMessage.new
          message.chat = channel
          message.text = app_text
          message.send_with(bot)
        end
      end
    end
  end
end

bot.get_updates(fail_silently: true) do |message|

  saved_chat_id = message.chat.id

  puts "@#{message.from.username}: #{message.text}"
  command = message.get_command_for(bot)

  message.reply do |reply|
    case command
    when /start/i
      reply.text = "Здравствуйте! Я помогу вам узнать статус вашего приложения в Play Market. Введите package name приложения в формате com.company.app. Используйте команду /apps для вывода списка приложений."
    when /apps/i
      reply.text = "Список приложений:\n"
      if $apps_array.length() > 0 then
        $apps_array.each do |app|
          reply.text += app.app_name + " - " + app.make_the_request + "\n"
        end
      end
    else
      app = App.new (command)
      reply.text = app.make_the_request
      app.app_message = reply.text
    end
    puts "sending #{reply.text.inspect} to @#{message.from.username}"
    reply.send_with(bot)
  end
end
