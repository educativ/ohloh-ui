module WidgetsHelper
  def factoid_image_path(factoid)
    path =
      case factoid.human_rating
      when 'good' then '/assets/fact_good.png'
      when 'info' then '/assets/fact_info.png'
      when 'warning' then '/assets/fact_warning.png'
      when 'bad' then '/assets/fact_bad.png'
      else '/assets/fact_info.png'
      end
    widget_image_url path
  end

  def widget_image_url(source)
    source.starts_with?('http') ? source : asset_url(source)
  end

  def widget_ohloh_logo_url
    widget_image_url 'widget_logos/openhublogo.png'
  end

  def widget_url(widget, type)
    url_params = widget.vars.dup.delete_if { |k, _| k == "#{type}_id" }.merge(format: 'js')
    send("#{widget.name.underscore}_#{type}_#{controller_name}_url", widget.send(type), url_params)
  end

  def widget_url_without_format(widget, type)
    url_params = widget.vars.dup.delete_if { |k, _| k == "#{type}_id" }
    send("#{widget.name.underscore}_#{type}_#{controller_name}_url", widget.send(type), url_params)
  end

  def widget_iframe_style(widget)
    "height: #{widget.height}px; width: #{widget.width}px; border: none"
  end
end
