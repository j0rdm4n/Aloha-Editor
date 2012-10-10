
/*
The 2 base classes are Menu and MenuItem.
For a MenuBar the children can be MenuButtons (MenuItem w/ just text)
For a ToolBar the children can be ToolButtons (optional tooltip)

Menus:

MenuBar > ToolBar = [ MenuButton ] # changes the class of the bar
MenuButton > MenuItem # Only contains text and submenu

Menu = [ MenuItem | MenuGroup ]
MenuItem = { iconCls+, text, accel+, disabled?, checked?, visible?, submenu+, action() }

MenuGroup > Menu # Used for visually grouping MenuItems so they can scroll
Separator > MenuItem

# One-off cases: (for custom rendering)
Heading > MenuItem # Uses a different class so the text is different
MakeTable > Menu # Offers a 5*5 grid to create a new table

# Unused but worth noting (for completeness)
ColorPicker > Menu



Toolbars:

ToolBar > Menu = [ ToolButton ]

ToolButton > MenuItem = [ tooltop+, (checked means pressed) ]
*/

(function() {
  var __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  define(["jquery", "css!./appmenu.css"], function($) {
    var appmenu;
    appmenu = {};
    appmenu.MenuBase = (function() {

      function MenuBase() {}

      MenuBase.prototype._newDiv = function(cls, markup) {
        var $el;
        if (cls == null) cls = '';
        if (markup == null) markup = '<div></div>';
        $el = $(markup);
        $el.addClass(cls);
        $el.bind('mousedown', function(evt) {
          evt.stopPropagation();
          return evt.preventDefault();
        });
        return $el;
      };

      return MenuBase;

    })();
    appmenu.Menu = (function(_super) {

      __extends(Menu, _super);

      function Menu(items, cls) {
        var item, _i, _len, _ref;
        this.items = items != null ? items : [];
        if (cls == null) cls = null;
        this.el = this._newDiv('menu');
        if (cls != null) this.el.addClass(cls);
        _ref = this.items;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          this._closeEverythingBut(item);
          item.parent = this;
          this.el.append(item.el);
        }
      }

      Menu.prototype._closeEverythingBut = function(item) {
        var that;
        that = this;
        return item.el.bind('mouseenter', function() {
          var child, _i, _len, _ref, _results;
          _ref = that.items;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            if (child.subMenu && child !== item) {
              _results.push(child.subMenu._closeSubMenu());
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        });
      };

      Menu.prototype.prepend = function(item) {
        item.parent = this;
        this.items.unshift(item);
        return item.el.prependTo(this.el);
      };

      Menu.prototype.append = function(item) {
        item.parent = this;
        this.items.push(item);
        return item.el.appendTo(this.el);
      };

      Menu.prototype._setSelectedBubbledUp = function(child, dir) {
        var ariaDown, ariaLeft, ariaParent, ariaRight, ariaUp, that;
        that = this;
        child.setSelected(false);
        ariaParent = function() {
          that.setSelected(false);
          return that.parent.setSelected(that);
        };
        ariaUp = function() {
          var i, newSelection;
          i = that.items.indexOf(child);
          newSelection = that.items[(i + that.items.length - 1) % that.items.length];
          return newSelection._setSelected(true);
        };
        ariaDown = function() {
          var i, newSelection;
          i = that.items.indexOf(child);
          newSelection = that.items[(i + that.items.length + 1) % that.items.length];
          return newSelection._setSelected(true);
        };
        ariaLeft = function() {
          return that.parent._setSelectedBubbledUp(true, false);
        };
        ariaRight = function() {
          that.setSelected(false);
          return that.parent._setSelectedBubbledUp(true, true);
        };
        switch (dir) {
          case 'up':
            return ariaUp();
          case 'down':
            return ariaDown();
          case 'left':
            return ariaLeft();
          case 'right':
            return ariaRight();
        }
      };

      Menu.prototype._openSubMenuAt = function(position) {
        var $canvas, that;
        $canvas = $('body');
        position.top -= $canvas.scrollTop();
        position.left -= $canvas.scrollLeft();
        this.el.css(position).appendTo($canvas);
        this.el.show();
        this.isOpened = true;
        that = this;
        return $('body').one('mousedown', function() {
          return setTimeout(that._closeSubMenu.bind(that), 10);
        });
      };

      Menu.prototype._closeSubMenu = function() {
        var item, _i, _len, _ref;
        _ref = this.items;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          if (item.subMenu) item.subMenu._closeSubMenu();
        }
        this.el.hide();
        return this.isOpened = false;
      };

      Menu.prototype.setAccelContainer = function($keyBinder) {
        var item, _i, _len, _ref, _results;
        this.$keyBinder = $keyBinder;
        _ref = this.items;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.setAccelContainer(this.$keyBinder));
        }
        return _results;
      };

      return Menu;

    })(appmenu.MenuBase);
    appmenu.MenuItem = (function(_super) {

      __extends(MenuItem, _super);

      function MenuItem(text, conf) {
        var that, translated;
        this.text = text;
        if (conf == null) conf = {};
        MenuItem.__super__.constructor.call(this, 'menu-item');
        this.action = conf.action || null;
        this.iconCls = conf.iconCls || null;
        this.accel = conf.accel || null;
        if (this.accel) this.accel = this.accel.toLowerCase();
        this.isDisabled = conf.disabled || false;
        this.isChecked = conf.checked || false;
        this.isHidden = conf.hidden || false;
        this.subMenu = conf.subMenu || null;
        this.subMenuChar = conf.subMenuChar || '\u25B6';
        this.el = this._newDiv('menu-item');
        this.setIcon(this.iconCls);
        if (this.accel != null) {
          translated = this.accel.replace('Shift+', '⇧').replace('Meta+', '⌘');
          this._newDiv('accel').append(translated).appendTo(this.el);
          this.el.attr('title', "" + this.text + " (" + translated + ")");
        }
        this.setDisabled(this.isDisabled);
        this.setHidden(this.isHidden);
        this.setChecked(this.isChecked);
        if (this.text != null) {
          this._newDiv('text').append(this.text).appendTo(this.el);
        }
        if (this.subMenu != null) {
          this.el.addClass('submenu');
          this._newDiv('submenu').appendTo(this.el).append(this.subMenuChar);
        }
        that = this;
        this.setAction(this.action);
        this.setAccelContainer($(document));
        this.el.on('mouseenter', function(evt) {
          return that.setSelected(true);
        });
        this.el.on('mouseleave', function(evt) {
          return that.setSelected(false);
        });
        this._addEvents();
      }

      MenuItem.prototype._addEvents = function() {
        var that;
        if (this.subMenu != null) {
          that = this;
          return this.el.bind('mouseenter', function() {
            return that._openSubMenu(true);
          });
        }
      };

      MenuItem.prototype._openSubMenu = function(toTheRight) {
        var $parent, left, offset, parentOffset, position, top;
        if (toTheRight == null) toTheRight = false;
        if (this.subMenu != null) {
          offset = this.el.offset();
          $parent = this.el.offsetParent();
          parentOffset = $parent.offset();
          top = offset.top - parentOffset.top + $parent.position().top;
          left = offset.left - parentOffset.left + $parent.position().left;
          if (toTheRight) {
            left += this.el.outerWidth();
          } else {
            top += this.el.outerHeight();
          }
          position = {
            top: top,
            left: left
          };
          return this.subMenu._openSubMenuAt(position);
        }
      };

      MenuItem.prototype._closeSubMenu = function() {
        if (this.subMenu) return this.subMenu._closeSubMenu();
      };

      MenuItem.prototype._cssToggler = function(val, cls) {
        if (val) this.el.addClass(cls);
        if (!val) return this.el.removeClass(cls);
      };

      MenuItem.prototype.setIcon = function(iconCls) {
        this.iconCls = iconCls;
        if (this.iconCls != null) {
          this.el.addClass('icon');
          if (this.el.children('.menu-icon').length) {
            return this.el.children('.menu-icon').addClass(this.iconCls);
          } else {
            return this._newDiv('menu-icon').addClass(this.iconCls).prependTo(this.el);
          }
        } else {
          this.el.removeClass('icon');
          return this.el.children('.menu-icon').remove();
        }
      };

      MenuItem.prototype.setAction = function(action) {
        var that;
        this.action = action;
        that = this;
        this.el.off('click');
        this.el.bind('click', function(evt) {
          evt.preventDefault();
          return $('.menu').hide();
        });
        if (this.action) return this.el.bind('click', that.action);
      };

      MenuItem.prototype.setChecked = function(isChecked) {
        this.isChecked = isChecked;
        this._cssToggler(this.isChecked, 'checked');
        this.el.children('.checked-icon').remove();
        if (this.isChecked) {
          return this._newDiv('checked-icon').append('\u2713').appendTo(this.el);
        }
      };

      MenuItem.prototype.setDisabled = function(isDisabled) {
        this.isDisabled = isDisabled;
        this._cssToggler(this.isDisabled, 'disabled');
        if (this.isDisabled && this.action) {
          this.el.off('click', this.action);
          if (this.accel) {
            return this.el.unbind('keydown.appmenu', this.accel, this.action);
          }
        } else if (!this.isDisabled && this.action) {
          this.el.on('click', this.action);
          if (this.accel) {
            return this.el.bind('keydown.appmenu', this.accel, this.action);
          }
        }
      };

      MenuItem.prototype.setHidden = function(isHidden) {
        this.isHidden = isHidden;
        return this._cssToggler(this.isHidden, 'hidden');
      };

      MenuItem.prototype.setText = function(text) {
        this.text = text;
        return this.el.children('.text')[0].innerHTML = this.text;
      };

      MenuItem.prototype._setSelected = function(isSelected) {
        this.isSelected = isSelected;
        return this._cssToggler(this.isSelected, 'selected');
      };

      MenuItem.prototype.setSelected = function(isSelected) {
        var ariaDown, ariaEnter, ariaLeft, ariaParent, ariaRight, ariaUp, that;
        this._setSelected(isSelected);
        that = this;
        ariaParent = function(direction) {
          that.setSelected(false);
          that._closeSubMenu();
          return that.parent._setSelectedBubbledUp(that, direction);
        };
        ariaUp = function() {
          return ariaParent('up');
        };
        ariaDown = function() {
          return ariaParent('down');
        };
        ariaLeft = function() {
          return ariaParent('left');
        };
        ariaRight = function() {
          return ariaParent('right');
        };
        ariaEnter = function() {
          return that.action();
        };
        if (isSelected) {
          this.$keyBinder.bind('keydown.appmenuaria', 'up', ariaUp);
          this.$keyBinder.bind('keydown.appmenuaria', 'down', ariaDown);
          this.$keyBinder.bind('keydown.appmenuaria', 'left', ariaLeft);
          this.$keyBinder.bind('keydown.appmenuaria', 'right', ariaRight);
          return this.$keyBinder.bind('keydown.appmenuaria', 'enter', ariaEnter);
        } else {
          return this.$keyBinder.off('keydown.appmenuaria');
        }
      };

      MenuItem.prototype.setAccelContainer = function($keyBinder) {
        var that;
        if (this.$keyBinder) this.$keyBinder.unbind('keydown.appmenu');
        this.$keyBinder = $keyBinder;
        if ((this.accel != null) && this.$keyBinder) {
          that = this;
          if (this.action) {
            this.$keyBinder.bind('keydown.appmenu', this.accel, this.action);
          }
        }
        if (this.subMenu) return this.subMenu.setAccelContainer($keyBinder);
      };

      return MenuItem;

    })(appmenu.MenuBase);
    appmenu.Separator = (function(_super) {

      __extends(Separator, _super);

      function Separator() {
        Separator.__super__.constructor.call(this, null, {
          disabled: true
        });
        this.el.addClass('separator');
      }

      Separator.prototype._addEvents = function() {};

      return Separator;

    })(appmenu.MenuItem);
    appmenu.ToolBar = (function(_super) {

      __extends(ToolBar, _super);

      function ToolBar(items) {
        if (items == null) items = [];
        ToolBar.__super__.constructor.call(this, items);
        this.el.addClass('tool-bar');
        this.el.removeClass('menu');
      }

      ToolBar.prototype._closeSubMenu = function() {};

      return ToolBar;

    })(appmenu.Menu);
    appmenu.ToolButton = (function(_super) {

      __extends(ToolButton, _super);

      function ToolButton(text, conf) {
        conf.subMenuChar = '\u25BC';
        ToolButton.__super__.constructor.call(this, text, conf);
        this.el.addClass('tool-button');
        this.toolTip = conf.toolTip || null;
      }

      ToolButton.prototype._addEvents = function() {
        var that, tip;
        tip = this._newDiv('tool-tip').appendTo(this.el);
        if (this.toolTip != null) {
          tip.append(this.toolTip);
        } else {
          tip.append(this.text);
          if (this.accel) tip.append(" (" + this.accel + ")");
        }
        if (this.subMenu != null) {
          that = this;
          return this.el.bind('click', function() {
            return that._openSubMenu(false);
          });
        }
      };

      return ToolButton;

    })(appmenu.MenuItem);
    appmenu.MenuBar = (function(_super) {

      __extends(MenuBar, _super);

      function MenuBar(items) {
        var that;
        MenuBar.__super__.constructor.call(this, items);
        this.el.addClass('menu-bar');
        this.el.removeClass('menu');
        that = this;
        this.el.on('click', function(evt) {
          var item, _i, _len, _ref, _results;
          _ref = that.items;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            item = _ref[_i];
            if ($(evt.target).parent('.menu-item')[0] === item.el[0]) {
              _results.push(item._openSubMenu(false));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        });
      }

      MenuBar.prototype._closeSubMenu = function() {
        var item, _i, _len, _ref, _results;
        _ref = this.items;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item._closeSubMenu());
        }
        return _results;
      };

      return MenuBar;

    })(appmenu.Menu);
    appmenu.MenuButton = (function(_super) {

      __extends(MenuButton, _super);

      function MenuButton(text, subMenu) {
        MenuButton.__super__.constructor.call(this, text, {
          subMenu: subMenu
        });
        this.el.addClass('menu-button');
      }

      MenuButton.prototype._addEvents = function() {
        var that;
        that = this;
        return this.el.bind('mouseenter', function(evt) {
          var openMenu, _i, _len, _ref, _results;
          _ref = $('.menu');
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            openMenu = _ref[_i];
            if (openMenu !== that.el[0]) {
              _results.push($(openMenu).hide());
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        });
      };

      return MenuButton;

    })(appmenu.MenuItem);
    appmenu.custom = {};
    appmenu.custom.Heading = (function(_super) {

      __extends(Heading, _super);

      function Heading(markup, text, conf) {
        this.markup = markup;
        Heading.__super__.constructor.call(this, text, conf);
      }

      Heading.prototype._newDiv = function(cls) {
        var $el;
        if (cls === 'text') {
          $el = Heading.__super__._newDiv.call(this, cls, this.markup);
          $el.addClass('custom-heading');
          return $el;
        } else {
          return Heading.__super__._newDiv.call(this, cls);
        }
      };

      return Heading;

    })(appmenu.MenuItem);
    return appmenu;
  });

}).call(this);
