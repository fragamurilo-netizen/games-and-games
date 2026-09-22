(function(){
  'use strict';
  var desk=document.getElementById('go-editorial-desk'), sub=document.getElementById('go-editorial-primary');
  if(!desk||!sub)return;
  function sync(reset){
    Array.prototype.forEach.call(sub.options,function(option){var allowed=!option.dataset.desk||option.dataset.desk===desk.value;option.disabled=!allowed;option.hidden=!allowed;});
    if(reset||sub.selectedOptions.length&&sub.selectedOptions[0].disabled)sub.value='0';
    sub.disabled=!desk.value;
  }
  function dirty(){document.getElementById('go-editorial-structure-dirty').value='1';}
  desk.addEventListener('change',function(){dirty();sync(true);});sub.addEventListener('change',dirty);sync(false);
})();
