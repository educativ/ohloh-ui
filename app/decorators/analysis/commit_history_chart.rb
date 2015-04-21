class Analysis::CommitHistoryChart < Analysis::Chart
  def initialize(analysis)
    @analysis = analysis
    @history = Analysis::CommitHistory.new(analysis: analysis).execute
    @defaults = ANALYSIS_CHART_DEFAULTS.deep_merge(ANALYIS_CHARTS_OPTIONS['commits_history'])
  end

  def data
    series_and_range_data(@defaults.deep_merge(ANALYIS_CHARTS_OPTIONS['no_auxillaries']))
      .deep_merge(chart_watermark('watermark_440'))
  end

  private

  def series_data_map
    [series_data_without_axis_data, x_and_y_axis_data]
  end

  def series_data_without_axis_data
    series.select { |data| data.month < latest_date }.map { |h| [h.ticks, h.commits] }
  end

  def x_and_y_axis_data
    [{ 'x' => series.last.ticks, 'y' => series.last.commits }]
  end
end
