
#  set timeout for qei
def set_qei_timeout()
  if (!$qd2_cookie.nil? && !$qd2_cookie.empty?)
    if (!$qei_page_timeout_increment.nil? && !$qei_page_timeout_increment.empty?)
      $page_timeout = ($qei_page_timeout_increment.to_f) * ($page_timeout.to_i)
    end
  end
end

# checks if the string is a number
def is_numeric(str)
  true if Integer(str) rescue false
end