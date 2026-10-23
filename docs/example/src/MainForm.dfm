object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Shapes'
  ClientHeight = 240
  ClientWidth = 320
  object ButtonArea: TButton
    Left = 16
    Top = 16
    Width = 120
    Height = 25
    Caption = 'Total area'
    OnClick = ButtonAreaClick
  end
  object LabelResult: TLabel
    Left = 16
    Top = 56
    Caption = '0'
  end
end
