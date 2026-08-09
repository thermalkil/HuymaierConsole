from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'HuymaierShellRedesign.ps1'
text = PATH.read_text(encoding='utf-8-sig')

old_update = """function Update-HcChoicePopupVisuals {
    for($i=0;$i -lt @($script:HcChoiceButtons).Count;$i++){$b=$script:HcChoiceButtons[$i];if($i -eq $script:HcChoiceSelected){$b.Background='#E7C45E';$b.Foreground='#10151D';$b.BorderBrush='#FFF0A0';$b.BorderThickness='2'}else{$b.Background='#E8141C28';$b.Foreground='White';$b.BorderBrush='#43536A';$b.BorderThickness='1'}}
}"""
new_update = """function Update-HcChoicePopupVisuals {
    for($i=0;$i -lt @($script:HcChoiceButtons).Count;$i++){
        $b=$script:HcChoiceButtons[$i]
        $label=$(if($i -lt @($script:HcChoiceOptions).Count){[string]$script:HcChoiceOptions[$i]}else{''})
        if($i -eq $script:HcChoiceSelected){
            $b.Content=('▶  '+$label);$b.Background='#FFE7C45E';$b.Foreground='#FF10151D';$b.BorderBrush='#FFFFF0A0';$b.BorderThickness='2';$b.FontWeight='Bold';$b.Opacity=1.0
        }else{
            $b.Content=('    '+$label);$b.Background='#F21A2433';$b.Foreground='#FFF4F7FB';$b.BorderBrush='#FF43536A';$b.BorderThickness='1';$b.FontWeight='SemiBold';$b.Opacity=.92
        }
        try{$b.InvalidateVisual();$b.UpdateLayout()}catch{}
    }
}"""
if text.count(old_update) != 1:
    raise RuntimeError(f'Update-HcChoicePopupVisuals match count: {text.count(old_update)}')
text = text.replace(old_update, new_update, 1)

old_loop = "$script:HcChoiceButtons=@();for($i=0;$i -lt $script:HcChoiceOptions.Count;$i++){$b=New-Object System.Windows.Controls.Button;$b.Tag=$i;$b.Content=[string]$script:HcChoiceOptions[$i];$b.Height=58;$b.Margin='0,0,0,8';$b.Padding='18,8';$b.HorizontalContentAlignment='Left';$b.FontSize=18;$b.Cursor='Hand';$b.Focusable=$false;$b.IsTabStop=$false;$b.Add_Click({param($sender,$e)$script:HcChoiceSelected=[int]$sender.Tag;Invoke-HcChoicePopupSelected});$stack.Children.Add($b)|Out-Null;$script:HcChoiceButtons+=$b}"
new_loop = "$choiceTemplate=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" TargetType=\"Button\"><Border Background=\"{TemplateBinding Background}\" BorderBrush=\"{TemplateBinding BorderBrush}\" BorderThickness=\"{TemplateBinding BorderThickness}\" CornerRadius=\"11\" Padding=\"{TemplateBinding Padding}\"><ContentPresenter HorizontalAlignment=\"{TemplateBinding HorizontalContentAlignment}\" VerticalAlignment=\"Center\"/></Border></ControlTemplate>');$script:HcChoiceButtons=@();for($i=0;$i -lt $script:HcChoiceOptions.Count;$i++){$b=New-Object System.Windows.Controls.Button;$b.Template=$choiceTemplate;$b.Tag=$i;$b.Content=('    '+[string]$script:HcChoiceOptions[$i]);$b.Height=58;$b.Margin='0,0,0,8';$b.Padding='18,8';$b.HorizontalContentAlignment='Left';$b.FontSize=18;$b.Cursor='Hand';$b.Focusable=$false;$b.IsTabStop=$false;$b.Add_Click({param($sender,$e)$script:HcChoiceSelected=[int]$sender.Tag;Update-HcChoicePopupVisuals;Invoke-HcChoicePopupSelected});$stack.Children.Add($b)|Out-Null;$script:HcChoiceButtons+=$b}"
if text.count(old_loop) != 1:
    raise RuntimeError(f'choice button loop match count: {text.count(old_loop)}')
text = text.replace(old_loop, new_loop, 1)

PATH.write_text(text, encoding='utf-8')
print('Popup visual selection feedback upgraded with explicit Huymaier template and moving marker.')
