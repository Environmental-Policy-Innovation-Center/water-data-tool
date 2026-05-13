class Filters::CategoryComponentPreview < Lookbook::Preview
  # @label Default (white text on gray — standard panel)
  def default
    render Filters::CategoryComponent.new(label: "Violations") do
      tag.ul(class: "my-[6px] mb-[10px] mx-0 list-none px-1") do
        tag.li("Open violations", class: "px-[15px] py-1.5 text-sm")
      end
    end
  end

  # @label Light (dark text on white — More panel)
  def light
    render Filters::CategoryComponent.new(label: "Financial", variant: :light) do
      tag.ul(class: "my-[6px] mb-[10px] mx-0 list-none px-1") do
        tag.li("Annual water and sewer bill", class: "px-[15px] py-1.5 text-sm")
      end
    end
  end
end
