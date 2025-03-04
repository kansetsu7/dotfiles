# require 'amazing_print'
# AmazingPrint.pry!

Pry.commands.alias_command 'ep', 'exit-program'

if defined?(PryByebug)
  Pry.commands.alias_command 'c',   'continue'
  Pry.commands.alias_command 's',   'step'
  Pry.commands.alias_command 'n',   'next'
  Pry.commands.alias_command 'f',   'finish'
  Pry.commands.alias_command 'clr', '.clear'

  # Hit Enter to repeat last command
  Pry::Commands.command(/^$/, "repeat last command") do
    pry_instance.run_command Pry.history.to_a.last
  end
end

Pry.commands.alias_command 'd-p', 'disable-pry'

Pry::Commands.create_command 'load_tools' do
  group 'All'
  description 'load ./tmp/tools'
  def process
    # raise Pry::CommandError, "Wrong number of arguments (given 0, expected at least 1) " if args.empty?
    if args.empty?
      path = "./tmp/tools/tester.rb"
      res  = load path
      puts "load #{path} = #{res}"
    else
      args.map do |file_name|
        path = "./tmp/tools/#{file_name.underscore}.rb"
        res  = load path
        puts "load #{path} = #{res}"
      end
    end
  end
end
Pry.commands.alias_command('loadt', 'load_tools')


Pry::Commands.create_command 'rlt!' do
  group 'All'
  description 'reload! && load ./tmp/tools and run it'
  def process
    reload!
    load "./tmp/tools/tester.rb"
    Tester.go
  end
end

Pry::Commands.create_command 'lt!' do
  group 'All'
  description 'load ./tmp/tools and run it'
  def process
    load "./tmp/tools/tester.rb"
    Tester.go
  end
end

Pry::Commands.create_command 'nerv_caller' do
  group 'All'
  description 'grab callers from nerv'
  def process
    caller.select{|c| c =~ /proj/}
  end
end

Pry::Commands.create_command 'reconnect_db' do
  group 'All'
  description 'Reconnect db'
  def process
    ActiveRecord::Base.connection.reconnect!
    puts 'DB reconnected!'
  end
end
Pry.commands.alias_command('rcdb', 'reconnect_db')

# Nerv {{{
if defined?(Nerv)
  CDD = ClientDueDiligenceEvent
  CMB = CommissionBatch
  CSR = ClientServiceRecord
  CV  = CrsValuation
  ET  = EmailTemplate
  FDO = FundDealingOrder
  FI  = FinalizedInfo
  FII = FinalizedInfoItem
  IQ  = Inquiry
  ITB = ItemTransferBatch
  MP  = MasterPlan
  PA  = PaymentArrangement
  PC  = ProductConfig
  PI  = PlanItem
  PO  = PlanOwner
  POI = PayoutItem
  PS  = PlanService
  SRT = ServiceRecordType
  TB  = TransferBatch
  TU  = TopUp
  WCC = WorldCheckCase
  II  = InitialInstallment

  module Nerv::Pry
    RESOURCE_TYPES = {
      bp:    'BasicPlan',
      tu:    'TopUp',
      mp:    'MasterPlan',
      sr:    'ServiceRecord',
      cb:    'ContributionBatch',
      cmb:   'CommissionBatch',
      cc:    'ContributionCollection',
      cr:    'ContributionRecord',
      pd:    'PlanDealing',
      pdi:   'PlanDealingItem',
      fd:    'FundDealing',
      fdi:   'FundDealingItem',
      hd:    'Holding',
      ii:    'InitialInstallment',
      pc:    'Producer',
      producer: 'Producer',
      cl:    'Client',
      tb:    'TransferBatch',
      itb:   'ItemTransferBatch',
      mev:   'MonthEndValuation',
      imev:  'ItemMonthEndValuation',
      mevd:  'MonthEndValuationDetail',
      com_b: 'CommissionBatch',
      con_b: 'ContributionBatch',
      pa:    'PaymentArrangement',
      po:    'PlanOwner',
      iq:    'Inquiry',
    }

    DEV_PASSWORD = '666'
  end

  # nerv-resource {{{
  Pry::Commands.create_command 'nerv-resource' do
    group 'Nerv'
    description 'Get nerv resource and assign to variable'

    banner <<-BANNER
      Usage: nerv-resource TYPE QUERY
             nerv-resource TYPE QUERY [ --to VAR ]

      Get nerv resource by id or keyword, and assign it to a variable.
      Supported types:
        [#{Nerv::Pry::RESOURCE_TYPES.keys.join(' ')}]
        check `Nerv::Pry::RESOURCE_TYPES` for detail mapping

      Examples:

      nerv-resource sr 666               get SR #666 and assign to `sr`
      nerv-resource bp r1677 --to bp2    get BP R01001677 and assign to `bp2`
      nerv-resource fd2 42               get FD #42 and assign to `fd2`
      nerv-resource pdi 0                get frist PDI, 0 can be replaced by ^ or :first
      nerv-resource pdi -1               get last PDI, -1 can be replaced by $ or :last
      nerv-resource pdi                  get last item if no query given

      Append `;` to suppress the eval output.
      By default `=` is aliased to this command, try `=sr 666` shortcut usage.
    BANNER

    command_options :listing => "nerv-resource"

    def options(opt)
      opt.on '-t', '--to=', 'variable name to assign to'
    end

    def process
      type = args[0].to_s
      var  = opts.to? ? opts[:to] : type
      q    = args.from(1).join(' ').strip
      mod  = ''

      # 1st argument can be parsed as 'type + var'
      type = Nerv::Pry::RESOURCE_TYPES.keys.sort_by(&:length).reverse.detect do |short_name|
        type.start_with? short_name.to_s
      end

      if opts.to? && (args[0] != type.to_s) && (opts[:to] != args[0])
        msg = "WARNING: var name from arg (#{args[0]}) overwritten by option (#{opts[:to]})"
        output.puts _pry_.config.color ? Pry::Helpers::Text.bright_red(msg) : msg
      end

      raise Pry::CommandError, "Unknown resource type '#{type}'"          if type.nil?
      raise Pry::CommandError, "Invalid variable name '#{var}'"           if var !~ /\A[a-z0-9_]+\z/

      klass = Nerv::Pry::RESOURCE_TYPES.fetch(type)

      [q, var].each do |s|
        if %[;].include?(s[-1])
          s.chop!
          mod = ';'
        end
      end

      if q.empty? || %w[-1 $ :last].include?(q)
        cmd = "#{var} = #{klass}.last"
      elsif %w[0 ^ :first].include?(q)
        cmd = "#{var} = #{klass}.first"
      elsif q =~ /\A[a-z]/i || q =~ /\A0.+/
        case type
        when :bp
          plan_no = q.upcase
          cmd = "#{var} = BasicPlan.find_by(plan_no: '#{plan_no}')"
        when :tu
          plan_no = q.upcase.sub(/([A-Z]+)(\d*)(-001)?/) do |pn|
            template = pn.start_with?('C') ? '__010100' : '_0100100'
            $1 << template.from($1.size).first(9 - $1.size - $2.to_s.size).to_s << $2.to_s << '-001'
          end
          cmd = "#{var} = TopUp.find_by(plan_no: '#{plan_no}')"
        when :cl
          code = q.upcase.sub(/([A-Z]+)(\d*)/) do |cn|
            #  mt439 => MT000439
            $1 << $2.to_s.rjust(6, '0')
          end
          cmd = "#{var} = #{klass}.find_by(code: '#{code}')"
        when :pc
          cmd = "#{var} = #{klass}.find_by(code: '#{code}')"
        else
          raise Pry::CommandError, "Can't query #{klass} by string condition"
        end
      else
        cmd = "#{var} = #{klass}.find(#{q})"
      end

      eval_string << cmd << mod.to_s
    end
  end

  Pry.commands.alias_command('=', 'nerv-resource')
  Pry.commands.alias_command(/=((?:#{Nerv::Pry::RESOURCE_TYPES.keys.join('|')})\w*)/, "nerv-resource")
  # }}}

  # change-password {{{
  Pry::Commands.create_command 'change-password' do
    group 'Nerv'
    description 'Change user password for development convenience'

    banner <<-BANNER
      Usage: change-password mt000439     Change user with specific login_id
             change-password              Change users (predefined within snippet)
    BANNER

    def process
      login = args.shift

      if login.blank?
        play_snippet
      else
        puts '-----------'
        fail "args: #{args}, login: #{login}"
        login.downcase!
        cmd = <<-END.gsub(/^\s{4}/, '')
          User.find_by!(login_id: '#{login}').tap do |u|
            u.skip_confirmation! unless u.confirmed?
            u.skip_password_checking = true
            u.update!(password: '#{Nerv::Pry::DEV_PASSWORD}', otp_required_for_login: false)
          end
        END
        eval_string << cmd
      end
    end

    private

    def play_snippet
      filename = 'change_passwords.rb'
      dirs = [
        Pathname.new('~/vm/scripts/nerv')
      ]
      src = dirs.map { |s| s + filename}.detect(&:file?)
      if src
        run 'play', src
      else
        output.puts "Snippet file '#{filename}' not found."
        output.puts "  Finding pathes: #{dirs.map(&:to_s).inspect}"
      end
      # TODO: return void
    end
  end
  Pry.commands.alias_command('chpw', 'change-password')
  # }}}

  # change-password-all {{{
  Pry::Commands.create_command 'change-password-all' do
    group 'Nerv'
    description 'Change users password for development convenience'

    banner <<-BANNER
      Usage: change-password-all R01834367        Change all users under specific plan
    BANNER

    def process
      plan_no   = args.join(' ').upcase
      login_ids = BasicPlan.find_by(plan_no: plan_no).plan_owners.map(&:client).pluck(:code)
      results   = []

      login_ids.each do |login_id|
        output = StringIO.new
        Pry.config.output = output

        Pry.run_command("change-password #{login_id}")

        results << output.string
      end

      puts results.join("\n")
    end
  end
  # }}}
  Pry.commands.alias_command('chpwa', 'change-password-all')
end
# }}}

# Amoeba {{{
if defined?(Amoeba)
  module Amoeba::Pry
    DEV_PASSWORD = '666'
  end
  # change-password {{{
  Pry::Commands.create_command 'change-password' do
    group 'Amoeba'
    description 'Change user password for development convenience'

    banner <<-BANNER
      Usage: change-password mt000439     Change user with specific login_id
             change-password              Change users (predefined within snippet)
    BANNER

    def process
      login = args.shift

      if login.blank?
        puts 'not support blank args for Amoeba'
      else
        login.downcase!
        cmd = <<-END.gsub(/^\s{4}/, '')
          User.find_by_login!('#{login}').tap do |u|
            u.password = '#{Amoeba::Pry::DEV_PASSWORD}'
            u.password_confirmation = '#{Amoeba::Pry::DEV_PASSWORD}'
            u.save
          end
        END
        eval_string << cmd
      end
    end
  end
end

# vim: filetype=ruby
