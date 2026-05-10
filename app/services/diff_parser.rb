class DiffParser
  def self.parse(diff_text)
    result = {}
    current_file = nil
    before_lines = []
    after_lines  = []
    in_hunk      = false

    diff_text.to_s.each_line do |line|
      if line.start_with?('diff --git')
        result[current_file] = { before: before_lines.join, after: after_lines.join } if current_file
        current_file = line.match(%r{diff --git a/(.*?) b/(.*)})[2].strip rescue nil
        before_lines, after_lines, in_hunk = [], [], false
      elsif line.start_with?('@@')
        in_hunk = true
      elsif in_hunk
        if    line.start_with?('-') && !line.start_with?('---') then before_lines << line[1..]
        elsif line.start_with?('+') && !line.start_with?('+++') then after_lines  << line[1..]
        elsif line.start_with?(' ')
          before_lines << line[1..]
          after_lines  << line[1..]
        end
      end
    end

    result[current_file] = { before: before_lines.join, after: after_lines.join } if current_file
    result
  end
end
