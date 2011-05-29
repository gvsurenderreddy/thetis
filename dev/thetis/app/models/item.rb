#
#= Item
#
#Original by::   Sysphonic
#Authors::   MORITA Shintaro
#Copyright:: Copyright (c) 2007-2011 MORITA Shintaro, Sysphonic. All rights reserved.
#License::   New BSD License (See LICENSE file)
#URL::   {http&#58;//sysphonic.com/}[http://sysphonic.com/]
#
#Item is the most elemental object on this system.
#It contains description(expected HTML-formatted by FCKeditor), 
#Images and Attachments and can be added Comments as response from readers.
#Items can have different means by its xtype attribute, such as a workflow
#or a project (this type of Item is often called 'Mission' on this system).
#
#== Note:
#
#* 
#
class Item < ActiveRecord::Base
  has_one :team, :dependent => :destroy
  has_one :workflow, :dependent => :destroy
  has_many :comments, :dependent => :destroy
  has_many :images, :dependent => :destroy, :order=>'images.xorder'
  has_many :attachments, :dependent => :destroy, :order=>'attachments.xorder'

  public::XTYPE_UNKNOWN = nil
  public::XTYPE_PROJECT = 'project'
  public::XTYPE_WORKFLOW = 'workflow'
  public::XTYPE_INFO = 'info'
  public::XTYPE_PROFILE = 'profile'
  public::XTYPE_RESEARCH = 'research'
  public::XTYPE_ZEPTAIR_DIST = 'zeptair_dist'
  public::XTYPE_ZEPTAIR_POST = 'zeptair_post'

  public::FOLDER_ALL = 'all'
  public::FOLDER_CURRENT = 'current'
  public::FOLDER_LOWER = 'lower'

  public::SORT_FIELD_DEFAULT = 'updated_at'
  public::SORT_DIRECTION_DEFAULT = 'DESC'

  validates_presence_of	:title


  #=== self.copies_folder
  #
  #Gets the name of the Copies Folder.
  #
  #return:: Name of the Copies Folder.
  #
  def self.copies_folder
    I18n.t('item.copies_folder')
  end

  #=== is_a_copy?
  #
  #Checks if the Item is a copy of the other Item.
  #
  #return:: true if the Item is a copy, false otherwise.
  #
  def is_a_copy?
    return !self.source_id.nil?
  end

  #=== self.profile_title_def
  #
  #Returns default title of the Profile-sheet.
  #
  #return:: Default title of the Profile-sheet.
  #
  def self.profile_title_def
    return I18n.t('item.profile_title')
  end

  #=== disp_registered_by
  #
  #Returns string to show User who registered this Item.
  #
  #_users_cache_:: Hash to accelerate response. {user_id, user_name}
  #return:: String to show User who registered this Item.
  #
  def disp_registered_by(users_cache = nil)

    user_name = User.get_name(self.user_id, users_cache)

    if self.original_by.nil?
      disp = user_name
    else
      disp = User.get_name(self.original_by, users_cache) + ' (' + I18n.t('item.owner') + ':' + user_name + ')'
    end
    return disp
  end

  #=== self.sort_opts
  #
  #Returns sort options of the Items.
  #
  #_excepts_:: Array of the fields to exclude (ex. [:xorder]).
  #return:: Array of options.
  #
  def self.sort_opts(excepts)
    excepts ||= []
    opts = []
    unless excepts.include?(:xorder)
      opts << [I18n.t('sort.specified')+I18n.t('sort.asc'), 'xorder ASC']
      opts << [I18n.t('sort.specified')+I18n.t('sort.desc'), 'xorder DESC']
    end
    unless excepts.include?(:id)
      opts << [I18n.t('activerecord.attributes.id')+I18n.t('sort.asc'), 'Item.id ASC']
      opts << [I18n.t('activerecord.attributes.id')+I18n.t('sort.desc'), 'Item.id DESC']
    end
    unless excepts.include?(:title)
      opts << [Item.human_attribute_name('title')+I18n.t('sort.asc'), 'title ASC']
      opts << [Item.human_attribute_name('title')+I18n.t('sort.desc'), 'title DESC']
    end
    unless excepts.include?(:folder_id)
      opts << [I18n.t('item.folder')+I18n.t('sort.asc'), 'folder_id ASC']
      opts << [I18n.t('item.folder')+I18n.t('sort.desc'), 'folder_id DESC']
    end
    unless excepts.include?(:updated_at)
      opts << [I18n.t('activerecord.attributes.updated_at')+I18n.t('sort.asc'), 'updated_at ASC']
      opts << [I18n.t('activerecord.attributes.updated_at')+I18n.t('sort.desc'), 'updated_at DESC']
    end
    unless excepts.include?(:public)
      opts << [Item.human_attribute_name('public')+I18n.t('sort.asc'), 'public ASC']
      opts << [Item.human_attribute_name('public')+I18n.t('sort.desc'), 'public DESC']
    end
    unless excepts.include?(:user_id)
      opts << [I18n.t('item.registered_by')+I18n.t('sort.asc'), 'Item.user_id ASC']
      opts << [I18n.t('item.registered_by')+I18n.t('sort.desc'), 'Item.user_id DESC']
    end
    return opts
  end

  #=== self.check_user_auth
  #
  #Checks user authority to read or write contents
  #of the Item.
  #(Without considering about User's authority.)
  #
  #_item_id_:: Item-ID.
  #_user_:: Target User.
  #_rxw_:: Specify 'r' to check read-authority, 'w' to write-authority.
  #_check_admin_:: Flag to consider about User's authority.
  #return:: true if specified user has authority, false otherwise.
  #
  def self.check_user_auth(item_id, user, rxw, check_admin)

    begin
      item = Item.find(folder_id)
    rescue StandardError => err
      Log.add_error(nil, err)
      retun false
    end

    return item.check_user_auth(user, rxw, check_admin)
  end

  #=== check_user_auth
  #
  #Checks user authority to read or write contents
  #of the Item.
  #
  #_user_:: Target User.
  #_rxw_:: Specify 'r' to check read-authority, 'w' to write-authority.
  #_check_admin_:: Flag to consider about User's authority.
  #return:: true if specified user has authority, false otherwise.
  #
  def check_user_auth(user, rxw, check_admin)

    if user.nil? and rxw == 'w'
      return false
    end

    if check_admin and !user.nil? and user.admin?(User::AUTH_ITEM)
      return true
    end

    if !user.nil? and rxw == 'r'

      if self.public and self.xtype == Item::XTYPE_PROFILE
        return true
      end

      unless self.workflow.nil?
        if self.workflow.get_target_users.include?(user.id)
          return true
        end
      end
    end

    unless Folder.check_user_auth(self.folder_id, user, rxw, false)
      return false
    end

    if rxw == 'r' and self.public
      return true
    end

    if !user.nil? and user.id == self.user_id
      return true
    end

    return false
  end

  #=== copy
  #
  #Copies the Item.
  #
  #_user_id_:: New owner's ID.
  #_folder_id_:: Parent Folder-ID.
  #_attrs_:: Array of symbols of required attributes. All if not specified.
  #return:: Instance of the copied Item.
  #
  def copy(user_id, folder_id, attrs=nil)

    item = Item.new_by_type(self.xtype, folder_id)

    item.title = self.title
    item.summary = self.summary
    item.description = self.description
    item.layout = self.layout
    item.public = self.public
    item.updated_at = self.updated_at
    item.created_at = self.created_at
    item.source_id = self.id
    if self.original_by.nil? and self.user_id != 0
      item.original_by = self.user_id
    else
      item.original_by = self.original_by
    end
    item.user_id = user_id

    class << item
      def record_timestamps; false; end
    end

    item.save!

    class << item
      remove_method :record_timestamps
    end

    # Workflow
    if attrs.nil? or attrs.include?(:workflow)
      unless self.workflow.nil?
        copied_workflow = self.workflow.copy(user_id, item.id)
      end
    end

    # Comments
    if attrs.nil? or attrs.include?(:comment)
      unless self.comments.nil?
        self.comments.each do |comment|
          comment.copy(item.id)
        end
      end
    end

    # Images
    if attrs.nil? or attrs.include?(:image)
      unless self.images.nil?
        self.images.each do |image|
          image.copy(item.id)
        end
      end
    end

    # Attachments
    if attrs.nil? or attrs.include?(:attachment)
      unless self.attachments.nil?
        self.attachments.each do |attachment|
          attachment.copy(item.id, item.user_id)
        end
      end
    end

    return item
  end

  #=== self.new_info
  #
  #Creates an info-type instance of Item.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Instance of the Item.
  #
  def self.new_info(folder_id)

    Item.new_by_type(XTYPE_INFO, folder_id)
  end

  #=== self.new_project
  #
  #Creates an project-type instance of Item.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Instance of the Item.
  #
  def self.new_project(folder_id)

    Item.new_by_type(XTYPE_PROJECT, folder_id)
  end

  #=== self.new_workflow
  #
  #Creates an workflow-type instance of Item.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Instance of the Item.
  #
  def self.new_workflow(folder_id)

    Item.new_by_type(XTYPE_WORKFLOW, folder_id)
  end

  #=== self.new_profile
  #
  #Creates an profile-type instance of Item.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Instance of the Item.
  #
  def self.new_profile(folder_id)

    Item.new_by_type(XTYPE_PROFILE, folder_id)
  end

  #=== self.new_research
  #
  #Creates an research-type instance of Item.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Instance of the Item.
  #
  def self.new_research(folder_id)

    Item.new_by_type(XTYPE_RESEARCH, folder_id)
  end

  #=== self.new_by_type
  #
  #Creates an Item instance with specified type(xtype) and Folder-ID.
  #
  #Its xorder attribute is also automatically calicurated from Folder-ID, 
  #but note that if you don't save it immediately (that means, in a critical section),
  #you should update xorder before saving it.
  #
  #_type_:: Type of the Item.
  #_folder_id_:: Parent Folder-ID.
  #return:: An Item instance.
  #
  def self.new_by_type(type, folder_id)

    item = Item.new
    item.xtype = type
    item.folder_id = folder_id
    item.xorder = Item.get_order_max(folder_id) + 1

    return item
  end

  #=== update_attributes
  #
  #Updates attributes of the Item.
  #
  #This method overrides ActionRecord::Base.update_attributes() to
  #control updating 'update_at' attribute. We need to chage
  #orders to display (xorder) without updating it.
  #
  #And also calicurates order(xorder) in the parent Folder if required.
  #
  #_attrs_:: Hash of attributes to update.
  #
  def update_attributes(attrs)

    unless (attrs.keys & ['title', 'summary', 'description', 'xtype']).empty?
      self.updated_at = Time.now
    end

    if attrs.key?(:folder_id) and self.folder_id.to_s != attrs[:folder_id].to_s
      self.xorder = Item.get_order_max(attrs[:folder_id]) + 1
    end

    # Neccessary to change orders to display (xorder) without updating 'update_at' attribute.
    class << self
      def record_timestamps; false; end
    end

    super(attrs)

    class << self
      remove_method :record_timestamps
    end
  end

  #=== update_attribute
  #
  #Updates attributes of the Item.
  #
  #This method overrides ActionRecord::Base.update_attribute() to
  #control updating 'update_at' attribute. We need to change
  #orders to display (xorder) without updating it.
  #
  #And also calicurates order(xorder) in the parent Folder if required.
  #
  #_name_:: Name of the attribute to update.
  #_value_:: New value of the attribute.
  #
  def update_attribute(name, value)

    if ['title', 'summary', 'description', 'xtype'].include?(name)
      self.updated_at = Time.now
    end

    if name == :folder_id and self.folder_id.to_s != value.to_s
      self.xorder = Item.get_order_max(value) + 1
    end

    # Neccessary to change orders to display (xorder) without updating 'update_at' attribute.
    class << self
      def record_timestamps; false; end
    end

    super(name, value)

    class << self
      remove_method :record_timestamps
    end
  end

  #=== self.destroy
  #
  #Updates attributes of the Item.
  #
  #This method overrides ActionRecord::Base.destroy() to
  #handle the related attributes.
  #
  #_id_:: Target Item-ID.
  #
  def self.destroy(id)

    id.is_a?(Array) ? id.each { |id| destroy(id) } : find(id).destroy
  end

  #=== destroy
  #
  #Overrides ActionRecord::Base.destroy().
  #
  def destroy()

    team_folder = nil
    unless self.team.nil?
      team_folder = self.team.get_team_folder
    end

    # Team and Team Folder will be deleted automatically.
    super()

    # .. but when the item was in Team Folder, it remains.
    if !team_folder.nil? and team_folder.exists? and team_folder.count_items(true) <= 0
      team_folder.force_destroy
    end
  end

  #=== self.delete
  #
  #Overrides ActionRecord::Base.delete().
  #
  #_id_:: Target Item-ID.
  #
  def self.delete(id)

    Item.destroy(id)
  end

  #=== delete
  #
  #Overrides ActionRecord::Base.delete().
  #
  def delete()

    self.destroy
  end

  #=== self.destroy_all
  #
  #Overrides ActionRecord::Base.delete_all().
  #
  #_conditions_:: Conditions.
  #
  def self.destroy_all(conditions = nil)

    raise 'Use Item.destroy() instead of Item.destroy_all()!'
  end

  #=== self.delete_all
  #
  #Overrides ActionRecord::Base.delete_all().
  #
  #_conditions_:: Conditions.
  #
  def self.delete_all(conditions = nil)

    raise 'Use Item.destroy() instead of Item.delete_all()!'
  end

  #=== self.get_order_max
  #
  #Gets the maximum of order value of the specified (parent) Folder.
  #
  #_folder_id_:: Parent Folder-ID.
  #return:: Current maximum order.
  #
  def self.get_order_max(folder_id)

    begin
      max_order = Item.count_by_sql("SELECT MAX(xorder) FROM items where folder_id=#{folder_id}")
    rescue StandardError => err
      Log.add_error(nil, err)
    end

    max_order = 0 if max_order.nil?

    return max_order
  end

  #=== self.get_title
  #
  #Gets the title of the specified Item.
  #
  #_item_id_:: Item-ID.
  #return:: Item title. If not found, prearranged string.
  #
  def self.get_title(item_id)

    begin
      item = Item.find(item_id)
    rescue StandardError => err
      Log.add_error(nil, err)
    end
    if item.nil?
      return item_id.to_s + ' '+ I18n.t('paren.deleted')
    else
      return item.title
    end
  end

  #=== get_folder_path
  #
  #Gets Folder path in which this Item located.
  #
  #_folders_cache_:: Hash to accelerate response. {folder_id, path}
  #return:: Folder path like "/folder_name1/folder_name2".
  #
  def get_folder_path(folders_cache = nil)

    return Folder.get_path(self.folder_id, folders_cache)
  end

  #=== editable?
  #
  #Checks if the Item can be edited by specified User.
  #
  #_user_id_:: Operating User.
  #return:: true if the Item can be edited, false otherwise.
  #
  def editable?(user_id)

    if self.xtype == Item::XTYPE_WORKFLOW
      if !self.workflow.nil? and self.workflow.status != Workflow::STATUS_NOT_ISSUED
        return false
      end
    elsif self.xtype == Item::XTYPE_RESEARCH
      begin
        user = User.find(user_id)
        if user.admin?(User::AUTH_RESEARCH)
          return true
        end
      rescue StandardError => err
        Log.add_error(nil, err)
      end
    end

    return self.user_id == user_id.to_i
  end

  #=== movable_wf?
  #
  #Checks if the Item has Workflow and can be moved by specified User.
  #
  #_user_id_:: Operating User.
  #return:: true if the Item has Workflow and can be moved, false otherwise.
  #
  def movable_wf?(user_id)

    if self.xtype == Item::XTYPE_WORKFLOW
      if !self.workflow.nil? and self.workflow.decided?
        return (self.user_id == user_id.to_i)
      end
    end

    return false
  end

  #=== deletable?
  #
  #Checks if the Item can be deleted by specified User.
  #
  #_user_id_:: Operating User.
  #_admin_:: Specify administrative authority if necessary.
  #return:: true if the Item can be deleted, false otherwise.
  #
  def deletable?(user_id, admin=nil)

    if admin.nil?
      admin = User.find(user_id).admin?(User::AUTH_ITEM)
    end

    return true if admin

    if self.xtype == Item::XTYPE_WORKFLOW
      if !self.workflow.nil? and self.workflow.status == Workflow::STATUS_ACTIVE
        return false
      end
    end

    return self.user_id == user_id.to_i
  end

  #=== featured?
  #
  #Checks if the Item is now featured.
  #
  #return:: true if the Item is featured, false otherwise.
  #
  def featured?

    return false if self.updated_at.nil?

    return (Time.now < self.updated_at + 7*24*60*60)
  end

  #=== images_without_content
  #
  #Gets Images related to this Item without content.
  #
  #return:: Array of Images without content.
  #
  def images_without_content

    return [] if self.id.nil?

    sql = 'select id, title, memo, name, size, content_type, item_id, xorder, created_at, updated_at from images'
    sql << ' where item_id=' + self.id.to_s
    sql << ' order by xorder ASC'
    begin
      images = Image.find_by_sql(sql)
    rescue StandardError => err
      Log.add_error(nil, err)
    end

    return (images || [])
  end

  #=== attachments_without_content
  #
  #Gets Attachments related to this Item without content.
  #
  #return:: Array of Attachments without content.
  #
  def attachments_without_content

    return [] if self.id.nil?

    sql = 'select id, title, memo, name, size, content_type, item_id, xorder, location, digest_md5, created_at, updated_at from attachments'
    sql << ' where item_id=' + self.id.to_s
    sql << ' order by xorder ASC'
    begin
      attachments = Attachment.find_by_sql(sql)
    rescue StandardError => err
      Log.add_error(nil, err)
    end

    return (attachments || [])
  end

  #=== get_applicants
  #
  #Gets applicants for the project.
  #
  #return:: Array of User-IDs of applicants.
  #
  def get_applicants

    return [] if self.comments.nil?

    ary = []

    self.comments.each do |comment|
      next unless comment.xtype == Comment::XTYPE_APPLY

      ary << comment.user_id.to_s
    end

    return ary.uniq
  end

  #=== self.get_toys
  #
  #Gets Toys (desktop items) of specified User.
  #
  #_user_:: The target User.
  #return:: Toys (desktop items) of specified User.
  #
  def self.get_toys(user)

    add_con = "((Item.xtype in ('#{Item::XTYPE_INFO}','#{Item::XTYPE_PROJECT}')) or ((Item.xtype = '#{Item::XTYPE_WORKFLOW}') and (Item.original_by is not null)))"
    sql = ItemsHelper.get_list_sql(user, nil, nil, nil, nil, 10, false, add_con)
    toys = []
    Item.find_by_sql(sql).each do |item|
      toys << Toy.copy(nil, item)
    end

    return toys
  end

  #=== self.get_feeds
  #
  #Gets Web feeds of specified User.
  #
  #_user_:: The target User.
  #_root_url_:: Root URL.
  #_users_cache_:: Hash to accelerate response. {user_id, user_name}
  #return:: Array of FeedEntry.
  #
  def self.get_feeds(user, root_url, users_cache = nil)

    entries = []

    add_con = "((Item.xtype in ('#{Item::XTYPE_INFO}','#{Item::XTYPE_PROJECT}')) or ((Item.xtype = '#{Item::XTYPE_WORKFLOW}') and (Item.original_by is not null)))"
    sql = ItemsHelper.get_list_sql(user, nil, nil, nil, nil, 10, false, add_con)
    Item.find_by_sql(sql).each do |item|
      feed_entry  = FeedEntry.new
      feed_entry.created_at      = item.created_at
      feed_entry.updated_at      = item.updated_at
      feed_entry.author          = item.disp_registered_by(users_cache)
      feed_entry.link            = root_url + ApplicationHelper.url_for(:controller => 'frames', :action => 'index', :default => ApplicationHelper.url_for(:controller => 'items', :action => 'show', :id => item.id))
      feed_entry.title           = '['+Item.human_name+'] '+item.title
      feed_entry.content     = (item.summary.nil?)?'(No summary)':(item.summary.gsub(/^(.{0,200}).*/m,"\\1"))
      if $thetis_config[:feed]['feed_content'] == '1' and !item.description.nil?
        feed_entry.content << "\n#{item.description}"
        feed_entry.content_encoded = "<![CDATA[#{item.description}]]>"
      end

      images = item.images_without_content
      if !images.nil? and images.length > 0
        feed_entry.enclosures = []

        img = images.first
        feed_enclosure = FeedEntry::FeedEnclosure.new
        feed_enclosure.url = root_url + ApplicationHelper.url_for(:controller => 'items', :action => 'get_image', :id => img.id, :rand => rand(10000000000))
        feed_enclosure.type = img.content_type
        feed_enclosure.length = img.size
        feed_enclosure.title = (img.title.nil? or img.title.empty?) ? img.name : img.title
        feed_entry.enclosures << feed_enclosure
      end
      entries << feed_entry
    end
    return entries
  end
end