defmodule Contex.BarChart do
  import Contex.SVG

  alias __MODULE__
  alias Contex.{Scale, ContinuousLinearScale, OrdinalScale}
  alias Contex.CategoryColourScale
  alias Contex.{Dataset, Mapping}
  alias Contex.Axis
  alias Contex.Utils

  defstruct [
    :dataset,
    :mapping,
    :options,
    :category_scale,
    :value_scale,
    :series_fill_colours,
    :phx_event_handler,
    :value_range,
    :select_item
  ]

  @required_mappings [
    category_col: :exactly_one,
    value_cols: :one_or_more
  ]

  @default_options [
    type: :stacked,
    orientation: :vertical,
    axis_label_rotation: :auto,
    custom_value_scale: nil,
    custom_value_formatter: nil,
    width: 100,
    height: 100,
    padding: 1,
    data_labels: true,
    colour_palette: :default,
    phx_event_handler: nil,
    phx_event_target: nil,
    select_item: nil
  ]

  @type t() :: %__MODULE__{}
  @type orientation() :: :vertical | :horizontal
  @type plot_type() :: :stacked | :grouped
  @type selected_item() :: %{category: any(), series: any()}

  @spec new(Contex.Dataset.t(), keyword()) :: Contex.BarChart.t()
  def new(%Dataset{} = dataset, options \\ []) when is_list(options) do
    options = Keyword.merge(@default_options, options)
    mapping = Mapping.new(@required_mappings, Keyword.get(options, :mapping), dataset)

    %BarChart{
      dataset: dataset,
      mapping: mapping,
      options: options
    }
  end

  @doc """
  Sets the default scales for the plot based on its column mapping.
  """
  @deprecated "Default scales are now silently applied"
  @spec set_default_scales(Contex.BarChart.t()) :: Contex.BarChart.t()
  def set_default_scales(%BarChart{mapping: %{column_map: column_map}} = plot) do
    set_cat_col_name(plot, column_map.category_col)
    |> set_val_col_names(column_map.value_cols)
  end

  @doc """
  Specifies whether data labels are shown on the bars
  """
  @deprecated "Set in new/2 options"
  @spec data_labels(Contex.BarChart.t(), boolean()) :: Contex.BarChart.t()
  def data_labels(%BarChart{} = plot, data_labels) do
    set_option(plot, :data_labels, data_labels)
  end

  @doc """
  Specifies whether the bars are drawn stacked or grouped.
  """
  @deprecated "Set in new/2 options"
  @spec type(Contex.BarChart.t(), plot_type()) :: Contex.BarChart.t()
  def type(%BarChart{} = plot, type) do
    set_option(plot, :type, type)
  end

  @doc """
  Specifies whether the bars are drawn horizontally or vertically.
  """
  @deprecated "Set in new/2 options"
  @spec orientation(Contex.BarChart.t(), orientation()) :: Contex.BarChart.t()
  def orientation(%BarChart{} = plot, orientation) do
    set_option(plot, :orientation, orientation)
  end

  @doc """
  Forces the value scale to the given data range
  """
  @spec force_value_range(Contex.BarChart.t(), {number, number}) :: Contex.BarChart.t()
  @deprecated "Use the `:custom_value_scale` option in `new/2`"
  def force_value_range(%BarChart{mapping: mapping} = plot, {min, max} = value_range)
      when is_number(min) and is_number(max) do
    %{plot | value_range: value_range}
    |> set_val_col_names(mapping.column_map.value_cols)
  end

  @doc false
  def set_size(%BarChart{} = plot, width, height) do
    plot
    |> set_option(:width, width)
    |> set_option(:height, height)
  end

  @doc """
  Specifies the label rotation value that will be applied to the bottom axis. Accepts integer
  values for degrees of rotation or `:auto`. Note that manually set rotation values other than
  45 or 90 will be treated as zero. The default value is `:auto`, which sets the rotation to
  zero degrees if the number of items on the axis is greater than eight, 45 degrees otherwise.
  """
  @deprecated "Set in new/2 options"
  @spec axis_label_rotation(Contex.BarChart.t(), integer() | :auto) :: Contex.BarChart.t()
  def axis_label_rotation(%BarChart{} = plot, rotation) when is_integer(rotation) do
    set_option(plot, :axis_label_rotation, rotation)
  end

  def axis_label_rotation(%BarChart{} = plot, _) do
    set_option(plot, :axis_label_rotation, :auto)
  end

  @doc """
  Specifies the padding between the category groups. Defaults to 2. Specified relative to the plot size.
  """
  @deprecated "Set in new/2 options"
  @spec padding(Contex.BarChart.t(), number) :: Contex.BarChart.t()
  def padding(%BarChart{} = plot, padding) when is_number(padding) do
    set_option(plot, :padding, padding)
  end

  @doc """
  Overrides the default colours.

  Colours can either be a named palette defined in `Contex.CategoryColourScale` or a list of strings representing hex code
  of the colour as per CSS colour hex codes, but without the #. For example:

    ```
    barchart = BarChart.colours(barchart, ["fbb4ae", "b3cde3", "ccebc5"])
    ```

    The colours will be applied to the data series in the same order as the columns are specified in `set_val_col_names/2`
  """
  @deprecated "Set in new/2 options"
  @spec colours(Contex.BarChart.t(), Contex.CategoryColourScale.colour_palette()) ::
          Contex.BarChart.t()
  def colours(%BarChart{} = plot, colour_palette) when is_list(colour_palette) do
    set_option(plot, :colour_palette, colour_palette)
  end

  def colours(%BarChart{} = plot, colour_palette) when is_atom(colour_palette) do
    set_option(plot, :colour_palette, colour_palette)
  end

  def colours(%BarChart{} = plot, _) do
    set_option(plot, :colour_palette, :default)
  end

  @doc """
  Optionally specify a LiveView event handler. This attaches a `phx-click` attribute to each bar element.
  You can specify the event_target for LiveComponents - a `phx-target` attribute will also be attached.

  Note that it may not work with some browsers (e.g. Safari on iOS).
  """
  @deprecated "Set in new/2 options"
  def event_handler(%BarChart{} = plot, event_handler, event_target \\ nil) do
    plot
    |> set_option(:phx_event_handler, event_handler)
    |> set_option(:phx_event_target, event_target)
  end

  defp set_option(%BarChart{options: options} = plot, key, value) do
    options = Keyword.put(options, key, value)

    %{plot | options: options}
  end

  defp get_option(%BarChart{options: options}, key) do
    Keyword.get(options, key)
  end

  @doc """
  Highlights a selected value based on matching category and series.
  """
  @spec select_item(Contex.BarChart.t(), selected_item()) :: Contex.BarChart.t()
  def select_item(%BarChart{} = plot, select_item) do
    set_option(plot, :select_item, select_item)
  end

  @doc ~S"""
  Allows the axis tick labels to be overridden. For example, if you have a numeric representation of money and you want to
  have the value axis show it as millions of dollars you might do something like:

        # Turns 1_234_567.67 into $1.23M
        defp money_formatter_millions(value) when is_number(value) do
          "$#{:erlang.float_to_binary(value/1_000_000.0, [decimals: 2])}M"
        end

        defp show_chart(data) do
          BarChart.new(data)
          |> BarChart.custom_value_formatter(&money_formatter_millions/1)
        end

  """
  @spec custom_value_formatter(Contex.BarChart.t(), nil | fun) :: Contex.BarChart.t()
  @deprecated "Set in new/2 options"
  def custom_value_formatter(%BarChart{} = plot, custom_value_formatter)
      when is_function(custom_value_formatter) or custom_value_formatter == nil do
    set_option(plot, :custom_value_formatter, custom_value_formatter)
  end

  @doc false
  def get_legend_scales(%BarChart{options: options} = plot) do
    plot = prepare_scales(plot)
    scale = plot.series_fill_colours

    orientation = Keyword.get(options, :orientation)
    type = Keyword.get(options, :type)

    invert = orientation == :vertical and type == :stacked

    scale =
      if invert do
        CategoryColourScale.invert(scale)
      else
        scale
      end

    [scale]
  end

  @doc false
  def to_svg(%BarChart{options: options} = plot, plot_options) do
    # TODO: Some kind of option validation before removing deprecated option functions
    plot = prepare_scales(plot)
    category_scale = plot.category_scale
    value_scale = plot.value_scale

    orientation = Keyword.get(options, :orientation)
    plot_options = refine_options(plot_options, orientation)

    category_axis = get_category_axis(category_scale, orientation, plot)

    value_axis = get_value_axis(value_scale, orientation, plot)
    plot = %{plot | value_scale: value_scale, select_item: get_option(plot, :select_item)}

    cat_axis_svg = if plot_options.show_cat_axis, do: Axis.to_svg(category_axis), else: ""

    val_axis_svg = if plot_options.show_val_axis, do: Axis.to_svg(value_axis), else: ""

    [
      cat_axis_svg,
      val_axis_svg,
      "<g>",
      get_svg_bars(plot),
      "</g>"
    ]
  end

  defp refine_options(options, :horizontal),
    do:
      options
      |> Map.put(:show_cat_axis, options.show_y_axis)
      |> Map.put(:show_val_axis, options.show_x_axis)

  defp refine_options(options, _),
    do:
      options
      |> Map.put(:show_cat_axis, options.show_x_axis)
      |> Map.put(:show_val_axis, options.show_y_axis)

  defp get_category_axis(category_scale, :horizontal, plot) do
    Axis.new_left_axis(category_scale) |> Axis.set_offset(get_option(plot, :width))
  end

  defp get_category_axis(category_scale, _, plot) do
    rotation =
      case get_option(plot, :axis_label_rotation) do
        :auto ->
          if length(Scale.ticks_range(category_scale)) > 8, do: 45, else: 0

        degrees ->
          degrees
      end

    category_scale
    |> Axis.new_bottom_axis()
    |> Axis.set_offset(get_option(plot, :height))
    |> Kernel.struct(rotation: rotation)
  end

  defp get_value_axis(value_scale, :horizontal, plot),
    do: Axis.new_bottom_axis(value_scale) |> Axis.set_offset(get_option(plot, :height))

  defp get_value_axis(value_scale, _, plot),
    do: Axis.new_left_axis(value_scale) |> Axis.set_offset(get_option(plot, :width))

  defp get_svg_bars(%BarChart{mapping: %{column_map: column_map}, dataset: dataset} = plot) do
    series_fill_colours = plot.series_fill_colours

    fills =
      Enum.map(column_map.value_cols, fn column ->
        CategoryColourScale.colour_for_value(series_fill_colours, column)
      end)

    dataset.data
    |> Enum.map(fn row -> get_svg_bar(row, plot, fills) end)
  end

  defp get_svg_bar(
         row,
         %BarChart{mapping: mapping, category_scale: category_scale, value_scale: value_scale} =
           plot,
         fills
       ) do
    cat_data = mapping.accessors.category_col.(row)
    series_values = Enum.map(mapping.accessors.value_cols, fn value_col -> value_col.(row) end)

    cat_band = OrdinalScale.get_band(category_scale, cat_data)
    bar_values = prepare_bar_values(series_values, value_scale, get_option(plot, :type))
    labels = Enum.map(series_values, fn val -> Scale.get_formatted_tick(value_scale, val) end)
    event_handlers = get_bar_event_handlers(plot, cat_data, series_values)
    opacities = get_bar_opacities(plot, cat_data)

    get_svg_bar_rects(cat_band, bar_values, labels, plot, fills, event_handlers, opacities)
  end

  defp get_bar_event_handlers(%BarChart{mapping: mapping} = plot, category, series_values) do
    handler = get_option(plot, :phx_event_handler)
    target = get_option(plot, :phx_event_target)

    base_opts =
      case target do
        nil -> [phx_click: handler]
        "" -> [phx_click: handler]
        _ -> [phx_click: handler, phx_target: target]
      end

    case handler do
      nil ->
        Enum.map(mapping.column_map.value_cols, fn _ -> [] end)

      "" ->
        Enum.map(mapping.column_map.value_cols, fn _ -> [] end)

      _ ->
        Enum.zip(mapping.column_map.value_cols, series_values)
        |> Enum.map(fn {col, value} ->
          Keyword.merge(base_opts, category: category, series: col, value: value)
        end)
    end
  end

  @bar_faded_opacity "0.3"
  defp get_bar_opacities(
         %BarChart{
           select_item: %{category: selected_category, series: _selected_series},
           mapping: mapping
         },
         category
       )
       when selected_category != category do
    Enum.map(mapping.column_map.value_cols, fn _ -> @bar_faded_opacity end)
  end

  defp get_bar_opacities(
         %BarChart{
           select_item: %{category: _selected_category, series: selected_series},
           mapping: mapping
         },
         _category
       ) do
    Enum.map(mapping.column_map.value_cols, fn col ->
      case col == selected_series do
        true -> ""
        _ -> @bar_faded_opacity
      end
    end)
  end

  defp get_bar_opacities(%BarChart{mapping: mapping}, _) do
    Enum.map(mapping.column_map.value_cols, fn _ -> "" end)
  end

  # Transforms the raw value for each series into a list of range tuples the bar has to cover, scaled to the display area
  defp prepare_bar_values(series_values, scale, :stacked) do
    {results, _last_val} =
      Enum.reduce(series_values, {[], 0}, fn data_val, {points, last_val} ->
        end_val = data_val + last_val
        new = {Scale.domain_to_range(scale, last_val), Scale.domain_to_range(scale, end_val)}
        {[new | points], end_val}
      end)

    Enum.reverse(results)
  end

  defp prepare_bar_values(series_values, scale, :grouped) do
    {scale_min, _} = Scale.get_range(scale)

    results =
      Enum.reduce(series_values, [], fn data_val, points ->
        range_val = Scale.domain_to_range(scale, data_val)
        [{scale_min, range_val} | points]
      end)

    Enum.reverse(results)
  end

  defp get_svg_bar_rects(
         {cat_band_min, cat_band_max} = cat_band,
         bar_values,
         labels,
         plot,
         fills,
         event_handlers,
         opacities
       )
       when is_number(cat_band_min) and is_number(cat_band_max) do
    count = length(bar_values)
    indices = 0..(count - 1)

    orientation = get_option(plot, :orientation)

    adjusted_bands =
      Enum.map(indices, fn index ->
        adjust_cat_band(cat_band, index, count, get_option(plot, :type), orientation)
      end)

    rects =
      Enum.zip([bar_values, fills, labels, adjusted_bands, event_handlers, opacities])
      |> Enum.map(fn {bar_value, fill, label, adjusted_band, event_opts, opacity} ->
        {x, y} = get_bar_rect_coords(orientation, adjusted_band, bar_value)
        opts = [fill: fill, opacity: opacity] ++ event_opts
        rect(x, y, title(label), opts)
      end)

    texts =
      case count < 4 and get_option(plot, :data_labels) do
        false ->
          []

        _ ->
          Enum.zip([bar_values, labels, adjusted_bands])
          |> Enum.map(fn {bar_value, label, adjusted_band} ->
            get_svg_bar_label(orientation, bar_value, label, adjusted_band, plot)
          end)
      end

    # TODO: Get nicer text with big stacks - maybe limit to two series
    [rects, texts]
  end

  defp get_svg_bar_rects(_x, _y, _label, _plot, _fill, _event_handlers, _opacities), do: ""

  defp adjust_cat_band(cat_band, _index, _count, :stacked, _), do: cat_band

  defp adjust_cat_band({cat_band_start, cat_band_end}, index, count, :grouped, :vertical) do
    interval = (cat_band_end - cat_band_start) / count
    {cat_band_start + index * interval, cat_band_start + (index + 1) * interval}
  end

  defp adjust_cat_band({cat_band_start, cat_band_end}, index, count, :grouped, :horizontal) do
    interval = (cat_band_end - cat_band_start) / count
    # Flip index so that first series is at top of group
    index = count - index - 1
    {cat_band_start + index * interval, cat_band_start + (index + 1) * interval}
  end

  defp get_bar_rect_coords(:horizontal, cat_band, bar_extents), do: {bar_extents, cat_band}
  defp get_bar_rect_coords(:vertical, cat_band, bar_extents), do: {cat_band, bar_extents}

  defp get_svg_bar_label(:horizontal, {_, bar_end} = bar, label, cat_band, _plot) do
    text_y = midpoint(cat_band)
    width = width(bar)

    {text_x, class, anchor} =
      case width < 50 do
        true -> {bar_end + 2, "exc-barlabel-out", "start"}
        _ -> {midpoint(bar), "exc-barlabel-in", "middle"}
      end

    text(text_x, text_y, label, text_anchor: anchor, class: class, dominant_baseline: "central")
  end

  defp get_svg_bar_label(_, {bar_start, _} = bar, label, cat_band, _plot) do
    text_x = midpoint(cat_band)

    {text_y, class} =
      case width(bar) > 20 do
        true -> {midpoint(bar), "exc-barlabel-in"}
        _ -> {bar_start - 10, "exc-barlabel-out"}
      end

    text(text_x, text_y, label, text_anchor: "middle", class: class)
  end

  @doc """
  Sets the category column name. This must exist in the dataset.

  This provides the labels for each bar or group of bars
  """
  @deprecated "Use `:mapping` option in `new/2`"
  def set_cat_col_name(%BarChart{mapping: mapping} = plot, cat_col_name) do
    mapping = Mapping.update(mapping, %{category_col: cat_col_name})

    %{plot | mapping: mapping}
  end

  @doc """
  Sets the value column names. Each must exist in the dataset.

  This provides the value for each bar.
  """
  @deprecated "Use `:mapping` option in `new/2`"
  def set_val_col_names(%BarChart{mapping: mapping} = plot, val_col_names)
      when is_list(val_col_names) do
    mapping = Mapping.update(mapping, %{value_cols: val_col_names})

    %{plot | mapping: mapping}
  end

  def set_val_col_names(%BarChart{} = plot, _), do: plot

  defp prepare_scales(%BarChart{} = plot) do
    plot
    |> prepare_value_scale()
    |> prepare_category_scale()
    |> prepare_colour_scale()
  end

  defp prepare_category_scale(
         %BarChart{dataset: dataset, options: options, mapping: mapping} = plot
       ) do
    padding = Keyword.get(options, :padding, 2)

    cat_col_name = mapping.column_map[:category_col]
    categories = Dataset.unique_values(dataset, cat_col_name)
    {r_min, r_max} = get_range(:category, plot)

    cat_scale =
      OrdinalScale.new(categories)
      |> Scale.set_range(r_min, r_max)
      |> OrdinalScale.padding(padding)

    %{plot | category_scale: cat_scale}
  end

  defp prepare_value_scale(%BarChart{dataset: dataset, mapping: mapping} = plot) do
    val_col_names = mapping.column_map[:value_cols]
    custom_value_scale = get_option(plot, :custom_value_scale)

    val_scale =
      case custom_value_scale do
        nil ->
          {min, max} =
            get_overall_value_domain(plot, dataset, val_col_names, get_option(plot, :type))
            |> Utils.fixup_value_range()

          ContinuousLinearScale.new()
          |> ContinuousLinearScale.domain(min, max)
          |> struct(custom_tick_formatter: get_option(plot, :custom_value_formatter))

        _ ->
          custom_value_scale
      end

    {r_start, r_end} = get_range(:value, plot)
    val_scale = Scale.set_range(val_scale, r_start, r_end)

    %{plot | value_scale: val_scale, mapping: mapping}
  end

  defp prepare_colour_scale(%BarChart{mapping: mapping} = plot) do
    val_col_names = mapping.column_map[:value_cols]

    series_fill_colours =
      CategoryColourScale.new(val_col_names)
      |> CategoryColourScale.set_palette(get_option(plot, :colour_palette))

    %{plot | series_fill_colours: series_fill_colours, mapping: mapping}
  end

  defp get_range(:category, %BarChart{} = plot) do
    case get_option(plot, :orientation) do
      :horizontal -> {get_option(plot, :height), 0}
      _ -> {0, get_option(plot, :width)}
    end
  end

  defp get_range(:value, %BarChart{} = plot) do
    case get_option(plot, :orientation) do
      :horizontal -> {0, get_option(plot, :width)}
      _ -> {get_option(plot, :height), 0}
    end
  end

  defp get_overall_value_domain(%BarChart{value_range: {min, max}}, _, _, _), do: {min, max}

  defp get_overall_value_domain(_plot, dataset, col_names, :stacked) do
    {_, max} = Dataset.combined_column_extents(dataset, col_names)
    {0, max}
  end

  defp get_overall_value_domain(_plot, dataset, col_names, :grouped) do
    combiner = fn {min1, max1}, {min2, max2} ->
      {Utils.safe_min(min1, min2), Utils.safe_max(max1, max2)}
    end

    Enum.reduce(col_names, {nil, nil}, fn col, acc_extents ->
      inner_extents = Dataset.column_extents(dataset, col)
      combiner.(acc_extents, inner_extents)
    end)
  end

  defp midpoint({a, b}), do: (a + b) / 2.0
  defp width({a, b}), do: abs(a - b)
end
